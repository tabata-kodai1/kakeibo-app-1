#!/usr/bin/env bash
# CI（.github/workflows/ci.yml）と同じ検査をローカルで順に実行し、結果を一覧にする。
# 1 つ落ちても残りを実行する。ローカルで全部通れば CI も通る、という状態を保つのが目的
# （docs/non-functional.md N-16・N-34・N-35）。
#
# 前提: DB と API のコンテナが起動していること（bash .claude/skills/start-servers/start.sh）
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

results=()

# run <名前> <実行場所> <コマンド...>
run() {
  local name="$1" dir="$2"
  shift 2
  echo
  echo "=== ${name} ==="
  if (cd "$dir" && "$@"); then
    results+=("PASS  ${name}")
  else
    results+=("FAIL  ${name}")
  fi
}

# Ruby 側は API コンテナの中で動かす（ホストに Ruby を入れない前提）
in_api() { docker compose exec -T api "$@"; }

if ! docker compose ps --status running --services 2>/dev/null | grep -qx api; then
  echo "API コンテナが起動していない。先に bash .claude/skills/start-servers/start.sh を実行すること" >&2
  exit 2
fi

run "RuboCop"       . in_api bin/rubocop
run "Brakeman"      . in_api bin/brakeman --no-pager
run "bundler-audit" . in_api bin/bundler-audit

# rspec は開発 DB を壊さないよう、必ずテスト用 DB（*_test）に向ける（spec/rails_helper.rb の防護）。
# 接続先は、コンテナが持つ開発用の DATABASE_URL の DB 名だけ差し替えて作る
run "RSpec"         . in_api bash -c 'export RAILS_ENV=test DATABASE_URL="${DATABASE_URL/_development/_test}" && ./bin/rails db:prepare && bundle exec rspec'

run "ESLint"        frontend npm run lint
run "Prettier"      frontend npm run format:check
run "vue-tsc"       frontend npm run typecheck
run "npm audit"     frontend npm audit --audit-level=high

echo
echo "=== 結果 ==="
printf '%s\n' "${results[@]}"

if printf '%s\n' "${results[@]}" | grep -q '^FAIL'; then
  exit 1
fi
