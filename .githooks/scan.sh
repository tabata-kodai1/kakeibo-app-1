#!/bin/bash
# Git に入れてはいけない値・ファイルが、コミットや履歴に混ざっていないか検査する。
#
#   bash scan.sh                      ステージ済みの差分（コミット前）
#   bash scan.sh --range main..HEAD   コミット済みの履歴とコミットメッセージ（push 前）
#
# 1 件でも見つかれば終了コード 1。見つけた値そのものは出力しない（場所と規則名だけ）。
# 意図した例外の行には、行末に `secret-scan: allow` を書く（例: 雛形ファイルのダミー値）。

set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

MODE=staged
RANGE=""
if [ "${1:-}" = "--range" ]; then
  MODE=range
  RANGE="${2:?--range にはコミット範囲（例: main..HEAD）を指定する}"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FOUND=0

hit() { # 規則名 場所
  printf 'NG  %-28s %s\n' "$1" "$2"
  FOUND=1
}

# --- 1. 入れてはいけないファイル名 ---------------------------------------------
FORBIDDEN='(^|/)(\.env(\..*)?|.*\.tfvars(\.json)?|.*\.tfstate(\..*)?|.*\.tfplan|tfplan|backend\.hcl|master\.key|.*\.key|.*\.pem|.*\.p12|.*\.pfx|id_(rsa|ed25519|ecdsa)|\.npmrc|\.netrc|credentials\.json|service-account.*\.json|crash\.log)$'
# 雛形は入れてよい
ALLOWED_TEMPLATE='\.(example|sample|template)$'
DOTTF='(^|/)\.terraform/'

if [ "$MODE" = staged ]; then
  git diff --cached --name-only --diff-filter=ACMR > "$WORK/files"
else
  git log --name-only --format= "$RANGE" > "$WORK/files"
  sort -u -o "$WORK/files" "$WORK/files"
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if echo "$f" | grep -Eq "$DOTTF"; then
    hit "禁止パス(.terraform/)" "$f"
  elif echo "$f" | grep -Eq "$FORBIDDEN" && ! echo "$f" | grep -Eq "$ALLOWED_TEMPLATE"; then
    hit "禁止ファイル名" "$f"
  fi
done < "$WORK/files"

# --- 2. 追加された行の一覧（path:line:text）を作る -------------------------------
if [ "$MODE" = staged ]; then
  git diff --cached -U0 --no-color
else
  git log -p -U0 --no-color --format= "$RANGE"
fi | awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+\+\+ /    { file = ""; next }
  /^@@ /        { match($0, /\+[0-9]+/); line = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
  /^\+/         { if (file != "") { print file ":" line ":" substr($0, 2) } line++ }
' \
  | grep -Ev '^[^:]*(\.lock|package-lock\.json|\.lock\.hcl|\.svg):' \
  | grep -v 'secret-scan: allow' > "$WORK/added" || true

# コミットメッセージも同じ規則で調べる（履歴モードのみ）
: > "$WORK/messages"
if [ "$MODE" = range ]; then
  git log --format='<message %h>:0:%B' "$RANGE" | grep -v 'secret-scan: allow' > "$WORK/messages" || true
fi
cat "$WORK/added" "$WORK/messages" > "$WORK/all"

scan() { # 規則名 拡張正規表現 [-i]
  local name="$1" re="$2" flag="${3:-}"
  # shellcheck disable=SC2086
  grep -E $flag -e "$re" "$WORK/all" | while IFS= read -r l; do
    printf 'NG  %-28s %s\n' "$name" "$(echo "$l" | cut -d: -f1,2)"
  done
}

: > "$WORK/out"
{
  scan "AWSアクセスキー"       '(AKIA|ASIA)[0-9A-Z]{16}'
  scan "秘密鍵"                '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  scan "GitHubトークン"        'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}'
  scan "APIキー(sk-)"          'sk-[A-Za-z0-9_-]{20,}'
  scan "Slackトークン"         'xox[abprs]-[A-Za-z0-9-]{10,}'
  scan "Googleキー"            'AIza[0-9A-Za-z_-]{35}'
  scan "12桁の数字(AWSアカウントID?)" '(^|[^0-9])[0-9]{12}([^0-9]|$)'
  scan "AWSのホスト名(RDS/EC2等)" '[a-z0-9-]+\.[a-z0-9-]+\.(rds|elb)\.amazonaws\.com|ec2-[0-9-]+\..*compute\.amazonaws\.com'
  # scheme://user:pass@host。書式例のプレースホルダー（password、xxx、changeme など）は除く
  grep -E -e '[a-z][a-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]@$#{<]{4,}@' "$WORK/all" \
    | grep -Evi '://[^/:@]+:(password|passwd|pass|secret|xxx+|changeme|\*+|your[-_a-z]*)@' \
    | while IFS= read -r l; do
        printf 'NG  %-28s %s\n' "認証情報つきURL" "$(echo "$l" | cut -d: -f1,2)"
      done
  scan "秘密っぽい代入"        '(password|passwd|secret|token|api_?key|master_?key)[a-z_]*[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$#{<]{8,}["'"'"']' -i
} > "$WORK/out"

# --- 3. 公開してはいけない IPv4（プライベート・予約・ドキュメント用は除く）-------
grep -Eo '^[^:]+:[0-9]+:.*' "$WORK/all" | while IFS= read -r l; do
  loc=$(echo "$l" | cut -d: -f1,2)
  echo "$l" | cut -d: -f3- | grep -Eo '(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)' \
    | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | while IFS= read -r ip; do
      case "$ip" in
        10.*|127.*|0.0.0.0|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|169.254.*) continue ;;
        192.0.2.*|198.51.100.*|203.0.113.*) continue ;; # ドキュメント用（RFC 5737）
      esac
      # 各オクテットが 0-255 でなければ IP ではない（バージョン番号など）
      echo "$ip" | awk -F. '{ exit !($1<=255 && $2<=255 && $3<=255 && $4<=255) }' || continue
      printf 'NG  %-28s %s\n' "公開IPv4?" "$loc"
    done
done >> "$WORK/out"

# --- 4. この環境の実際の値との一致（一番確実な検査）-------------------------------
# Git 管理外（.gitignore 済み）の設定ファイルに書いてある値が、差分に混ざっていないか。
: > "$WORK/known"
git ls-files --others --ignored --exclude-standard 2>/dev/null \
  | grep -Ev '(^|/)(node_modules|vendor|\.terraform|dist|build|log|tmp|storage|\.git)/' \
  | grep -E '(^|/)(\.env(\..*)?|.*\.tfvars|backend\.hcl|master\.key|.*\.pem|credentials.*|secrets?(\..*)?)$' \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      [ "$(wc -c < "$f")" -le 65536 ] || continue
      # KEY=value / key = "value" 形式の右辺
      sed -nE 's/^[[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_.-]+[[:space:]]*[=:][[:space:]]*"?([^"#]+)"?[[:space:]]*(#.*)?$/\2/p' "$f"
      # 鍵ファイルなど、中身が 1 行の値そのもの
      [ "$(wc -l < "$f")" -le 1 ] && tr -d '\r\n' < "$f" && echo
    done >> "$WORK/known"
# いまの AWS アカウント ID（CLI が使えるときだけ）
if command -v aws >/dev/null 2>&1; then
  timeout 10 aws sts get-caller-identity --query Account --output text 2>/dev/null >> "$WORK/known" || true
fi
# 短い値（true、短い語など）は誤検出のもとなので 8 文字未満は捨てる
awk 'length($0) >= 8' "$WORK/known" | tr -d '\r' | sort -u > "$WORK/known.f"
if [ -s "$WORK/known.f" ]; then
  grep -F -f "$WORK/known.f" "$WORK/all" | while IFS= read -r l; do
    printf 'NG  %-28s %s\n' "この環境の実際の値と一致" "$(echo "$l" | cut -d: -f1,2)"
  done >> "$WORK/out"
fi

sort -u "$WORK/out" | grep '^NG' && FOUND=1

# --- 結果 ------------------------------------------------------------------------
VIS=$(gh repo view --json visibility -q .visibility 2>/dev/null || echo "不明")
echo
echo "対象: $([ "$MODE" = staged ] && echo 'ステージ済みの差分' || echo "履歴 $RANGE")  /  リポジトリ: $VIS"
if [ "$FOUND" -eq 0 ]; then
  echo "PASS: 混入は見つからなかった"
  exit 0
fi
echo "FAIL: 上の場所を確認する。意図した値なら行末に 'secret-scan: allow' を書く。本物なら消してから再実行する"
exit 1
