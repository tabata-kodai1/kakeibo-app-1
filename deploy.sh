#!/bin/bash
# 本番（AWS）へのデプロイ。手動で実行する（CD は採用しない。docs/tech-stack.md）。
#
#   bash deploy.sh             デプロイする
#   bash deploy.sh --dry-run   何も実行せず、やる手順だけを表示する（AWS に触れない）
#
# 手順:
#   1. フロントをビルドして S3 に同期する（Cache-Control を出し分ける。N-39）
#   2. バックエンドのソースを EC2 に送り、イメージをビルドしてコンテナを入れ替える（N-38）
#   3. db:migrate と db:seed を実行する
#   4. 疎通と CORS を確認する
#
# 前提:
#   - terraform apply 済みで、infra/ で `terraform init -backend-config=backend.hcl` 済み
#   - AWS CLI の認証済み、SSH の秘密鍵が ~/.ssh/id_ed25519（SSH_KEY で変更できる）
#   - infra/terraform.tfvars に db_password がある（RDS のパスワードの唯一の置き場）
#   - backend/config/master.key がある（RAILS_MASTER_KEY として使う）

set -euo pipefail

cd "$(dirname "$0")"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
CONTAINER=kakeibo-api
IMAGE=kakeibo-api

log() { printf '\n== %s\n' "$*"; }

# dry-run では実行せず、コマンドだけを表示する
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- 事前確認 -----------------------------------------------------------------
# EC2 に送るのは git archive（コミット済みのファイル）。未コミットの変更は届かないため、
# 「デプロイしたつもりで反映されていない」を避けるために止める。
if [ -n "$(git status --porcelain -- backend frontend)" ]; then
  echo "backend/ か frontend/ に未コミットの変更があります。コミットしてからデプロイしてください" >&2
  exit 1
fi
COMMIT="$(git rev-parse --short HEAD)"
log "デプロイするコミット: $COMMIT ($(git branch --show-current))"

# --- 設定値の取得 ---------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  API_IP="<api_ip>"
  BUCKET="<frontend_bucket>"
  FRONTEND_URL="<frontend_url>"
  RDS_HOST="<rds_endpoint>"
  DB_NAME="<db_name>"
  DB_USER="<db_username>"
else
  tf() { terraform -chdir=infra output -raw "$1"; }
  API_IP="$(tf api_ip)"
  BUCKET="$(tf frontend_bucket)"
  FRONTEND_URL="$(tf frontend_url)"
  RDS_HOST="$(tf rds_endpoint)"
  DB_NAME="$(tf db_name)"
  DB_USER="$(tf db_username)"
fi
API_URL="http://${API_IP}:3000"

SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes "ec2-user@${API_IP}")

# --- 1. フロント ----------------------------------------------------------------
log "1. フロントをビルドして S3 に同期する"
# VITE_API_BASE_URL はビルド時に埋め込まれる。本番は S3 と EC2 でオリジンが分かれるため、EC2 の URL を渡す
run env VITE_API_BASE_URL="$API_URL" npm --prefix frontend run build

# ハッシュ付きの JS / CSS（assets/）は中身が変わればファイル名も変わるので、長期キャッシュにしてよい。
# それ以外（index.html など）はファイル名が変わらないため、キャッシュさせない。
# 2 回に分けて同期する。--delete は各同期の範囲の中だけで効く。
run aws s3 sync frontend/dist/assets "s3://${BUCKET}/assets" \
  --delete --cache-control "public, max-age=31536000, immutable"
run aws s3 sync frontend/dist "s3://${BUCKET}" \
  --exclude "assets/*" --delete --cache-control "no-cache"

# --- 2. バックエンド ----------------------------------------------------------------
log "2. バックエンドを EC2 に送ってイメージをビルドし、コンテナを入れ替える"
# 初期化スクリプト（Docker とスワップの準備）の完了を待つ
run "${SSH[@]}" 'sudo cloud-init status --wait'

# ソースはコミット済みのものだけを標準入力で送る。master.key など Git 管理外のファイルは届かない。
# 1GB 程度のメモリでのビルドは、初期化スクリプトで確保したスワップに頼る。
if [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] git archive --format=tar HEAD:backend | ssh ... docker build -t %s -\n' "$IMAGE"
else
  git archive --format=tar HEAD:backend | "${SSH[@]}" "docker build -t ${IMAGE} -"
fi

# 旧コンテナを止めて入れ替える。数分の停止を許容する（N-38）。
run "${SSH[@]}" "docker rm -f ${CONTAINER} >/dev/null 2>&1 || true"

# 秘密（DB パスワード、マスターキー）は標準入力で渡す。
# コマンドライン引数だと EC2 の ps に出て、ファイルだと EC2 のディスクに残るため。
if [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] ssh ... docker run -d --name %s --restart unless-stopped -p 3000:3000 --env-file /dev/stdin %s   (DATABASE_URL / RAILS_MASTER_KEY / ALLOWED_ORIGINS は標準入力。表示しない)\n' "$CONTAINER" "$IMAGE"
else
  DB_PASSWORD="$(sed -nE 's/^[[:space:]]*db_password[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' infra/terraform.tfvars)"
  [ -n "$DB_PASSWORD" ] || { echo "infra/terraform.tfvars に db_password がありません" >&2; exit 1; }
  MASTER_KEY="$(tr -d '\r\n' < backend/config/master.key)"

  "${SSH[@]}" "docker run -d --name ${CONTAINER} --restart unless-stopped -p 3000:3000 --env-file /dev/stdin ${IMAGE}" >/dev/null <<ENV
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=1
RAILS_MASTER_KEY=${MASTER_KEY}
DATABASE_URL=mysql2://${DB_USER}:${DB_PASSWORD}@${RDS_HOST}:3306/${DB_NAME}
ALLOWED_ORIGINS=${FRONTEND_URL}
ENV
  unset DB_PASSWORD MASTER_KEY
fi

# 起動を待つ（bin/docker-entrypoint が db:prepare を実行してから Rails が立ち上がる）
if [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] ssh ... 起動を待つ（localhost:3000/up が 200 になるまで、最大 120 秒）\n'
else
  "${SSH[@]}" 'for i in $(seq 1 60); do curl -fsS -o /dev/null http://localhost:3000/up && exit 0; sleep 2; done; echo "API が 120 秒以内に起動しませんでした" >&2; docker logs --tail 50 '"${CONTAINER}"' >&2; exit 1'
fi

# --- 3. マイグレーションと初期データ -----------------------------------------------------
log "3. db:migrate と db:seed を実行する"
# db:seed は find_or_create_by! で、再実行してもカテゴリが重複しない
run "${SSH[@]}" "docker exec ${CONTAINER} ./bin/rails db:migrate db:seed"

# 古いイメージが溜まってディスクを埋めないようにする
run "${SSH[@]}" 'docker image prune -f >/dev/null'

# --- 4. 確認 ------------------------------------------------------------------
log "4. 疎通と CORS を確認する"
run curl -fsS -o /dev/null -w "API /up: %{http_code}\n" "${API_URL}/up"
run curl -fsS -o /dev/null -w "画面: %{http_code}\n" "${FRONTEND_URL}/"
# 画面のオリジンからの API 呼び出しに、許可のヘッダーが付くこと（N-12）。付かないと画面は出るのに API が全滅する
if [ "$DRY_RUN" -eq 1 ]; then
  printf '  [dry-run] curl -H "Origin: <frontend_url>" %s/api/health で Access-Control-Allow-Origin を確認\n' "$API_URL"
else
  if curl -fsS -D - -o /dev/null -H "Origin: ${FRONTEND_URL}" "${API_URL}/api/health" \
    | grep -qi "^access-control-allow-origin: ${FRONTEND_URL}"; then
    echo "CORS: OK"
  else
    echo "CORS: NG（Access-Control-Allow-Origin が付いていません）" >&2
    exit 1
  fi
fi

log "完了: ${FRONTEND_URL}"
