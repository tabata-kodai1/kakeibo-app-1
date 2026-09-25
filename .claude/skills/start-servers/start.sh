#!/usr/bin/env bash
# ローカル開発環境（DB・API・フロント）を 1 コマンドで起動する（docs/non-functional.md N-36）。
# 何度実行しても壊れないようにしてあり、起動済みのものは起動し直さない。
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# .env は Git にコミットしない（N-11）。なければひな形から作る
if [ ! -f .env ]; then
  cp .env.example .env
  echo "[start-servers] .env を .env.example から作成した"
fi

# DB と API。db は healthcheck 付きなので、healthy になるまで待つ。
# api の起動時に db:prepare が走る（backend/bin/docker-entrypoint）
docker compose up -d --wait db
docker compose up -d api

# api は healthcheck を持たないため、Rails の /up が 200 を返すまで自分で待つ
echo "[start-servers] API の起動を待っている（http://localhost:3000/up）"
for _ in $(seq 1 60); do
  if curl -fs -o /dev/null http://localhost:3000/up; then
    api_ready=1
    break
  fi
  sleep 2
done
if [ -z "${api_ready:-}" ]; then
  echo "[start-servers] API が 120 秒以内に起動しなかった。docker compose logs api を確認すること" >&2
  exit 1
fi

# フロント（Vite）。5173 が応答していれば起動済みとみなす
if curl -fs -o /dev/null http://localhost:5173; then
  echo "[start-servers] フロントは起動済み"
else
  (cd frontend && [ -d node_modules ] || npm ci)
  # ログは frontend/ に置く（.gitignore の対象）。バックグラウンドで動かし続ける
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
      # Git Bash では nohup + & だと、Windows のハンドル継承のせいで、呼び出し元が
      # パイプで出力を受けているとき Vite が生きている間は呼び出し元が終わらない。
      # Start-Process なら完全に切り離せる
      powershell.exe -NoProfile -Command "Start-Process -WindowStyle Hidden -WorkingDirectory frontend -FilePath cmd.exe -ArgumentList '/c','npm run dev > vite.log 2>&1'"
      ;;
    *)
      (cd frontend && nohup npm run dev >vite.log 2>&1 </dev/null &)
      ;;
  esac
  for _ in $(seq 1 30); do
    if curl -fs -o /dev/null http://localhost:5173; then
      front_ready=1
      break
    fi
    sleep 1
  done
  if [ -z "${front_ready:-}" ]; then
    echo "[start-servers] フロントが 30 秒以内に起動しなかった。frontend/vite.log を確認すること" >&2
    exit 1
  fi
fi

echo "[start-servers] 起動した: http://localhost:5173（API は 3000、DB は 3306）"
