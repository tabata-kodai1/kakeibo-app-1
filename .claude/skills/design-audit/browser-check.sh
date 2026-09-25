#!/usr/bin/env bash
# ブラウザ（Chrome）で画面を実際に操作し、設計書どおりに動くかを確認する。
# 専用の DB（kakeibo_e2e）・専用のポート（API 3001、Vite 5174）で隔離環境を立て、
# 確認が終わったら片付ける。開発用の DB・サーバー（3000・5173）には触れない。
#
# 前提: Docker、Node.js、Google Chrome が入っていること。DB のコンテナは、なければこのスクリプトが起動する。
# 依存の playwright-core はリポジトリに入れず、一時ディレクトリに入れる（package.json・CI に影響しない）。
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"
REPO_ROOT="$(pwd)"

WORK="${TMPDIR:-${TEMP:-/tmp}}/kakeibo-browser-check"
API_PORT=3001
UI_PORT=5174

cleanup() {
  docker rm -f e2e-api >/dev/null 2>&1
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      powershell.exe -NoProfile -Command "Get-NetTCPConnection -LocalPort ${UI_PORT} -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id \$_.OwningProcess -Force }" >/dev/null 2>&1
      ;;
    *)
      pkill -f "vite --port ${UI_PORT}" >/dev/null 2>&1
      ;;
  esac
  docker compose exec -T db mysql -uroot -pkakeibo -e "DROP DATABASE IF EXISTS kakeibo_e2e" >/dev/null 2>&1
}
trap cleanup EXIT

echo "[browser-check] 隔離環境を起動する（DB: kakeibo_e2e、API: ${API_PORT}、画面: ${UI_PORT}）"
docker compose up -d --wait db || exit 2
docker rm -f e2e-api >/dev/null 2>&1

# 開発用の API とは、DB・ポート・PID ファイルを分ける（ソースをバインドマウントしていて、
# tmp/pids/server.pid を共有すると起動できなくなる）
docker compose run -d --name e2e-api -p "${API_PORT}:3000" \
  -e DATABASE_URL="mysql2://root:kakeibo@db:3306/kakeibo_e2e" \
  api bash -c "./bin/rails db:prepare db:seed && exec ./bin/rails server -b 0.0.0.0 -p 3000 -P /tmp/e2e.pid" >/dev/null || exit 2

for _ in $(seq 1 60); do
  curl -fs -o /dev/null "http://localhost:${API_PORT}/up" && api_ready=1 && break
  sleep 2
done
if [ -z "${api_ready:-}" ]; then
  echo "[browser-check] 隔離 API が起動しなかった。docker logs e2e-api を確認すること" >&2
  exit 2
fi

# 画面は、隔離 API に向けた Vite を別ポートで起動する（vite.config.ts の API_PROXY_TARGET）
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    powershell.exe -NoProfile -Command "Start-Process -WindowStyle Hidden -WorkingDirectory frontend -FilePath cmd.exe -ArgumentList '/c','set API_PROXY_TARGET=http://localhost:${API_PORT}&& npx vite --port ${UI_PORT} --strictPort > vite-browser-check.log 2>&1'" >/dev/null
    ;;
  *)
    (cd frontend && API_PROXY_TARGET="http://localhost:${API_PORT}" nohup npx vite --port "${UI_PORT}" --strictPort >vite-browser-check.log 2>&1 </dev/null &)
    ;;
esac
for _ in $(seq 1 30); do
  curl -fs -o /dev/null "http://localhost:${UI_PORT}" && ui_ready=1 && break
  sleep 1
done
if [ -z "${ui_ready:-}" ]; then
  echo "[browser-check] 隔離した画面が起動しなかった。frontend/vite-browser-check.log を確認すること" >&2
  exit 2
fi

mkdir -p "$WORK"
cp .claude/skills/design-audit/browser-check.mjs "$WORK/browser-check.mjs"
if [ ! -d "$WORK/node_modules/playwright-core" ]; then
  (cd "$WORK" && { [ -f package.json ] || npm init -y >/dev/null 2>&1; } && npm i playwright-core >/dev/null 2>&1) || {
    echo "[browser-check] playwright-core を入れられなかった" >&2
    exit 2
  }
fi

echo "[browser-check] Chrome で操作する（約 2 分。応答なしの確認で 10 秒待つ場面がある）"
REPO_ROOT="$REPO_ROOT" SHOTS_DIR="$WORK" UI_URL="http://localhost:${UI_PORT}" API_URL="http://localhost:${API_PORT}" \
  node "$WORK/browser-check.mjs"
status=$?
echo "[browser-check] スクリーンショット: $WORK"
exit $status
