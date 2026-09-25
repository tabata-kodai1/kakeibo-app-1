---
name: start-servers
description: ローカル開発環境（MySQL・Rails API・Vite）を 1 コマンドで起動する。「サーバーを起動して」「画面を確認したい」「動作確認したい」のときに使う
---

# start-servers

`docker compose up`（DB・API）と `npm run dev`（フロント）の 2 手順を 1 コマンドにまとめる（[N-36](../../../docs/non-functional.md#開発プロセス品質)）。

## 使い方

リポジトリのどこからでも、次を実行する。

```
bash .claude/skills/start-servers/start.sh
```

スクリプトは次の順に進める。

1. `.env` がなければ `.env.example` から作る
2. `docker compose up -d --wait db` で DB が healthy になるまで待つ
3. `docker compose up -d api` で API を起動し、`http://localhost:3000/up` が 200 を返すまで待つ（起動時に `db:prepare` が走る）
4. `http://localhost:5173` が応答しなければ、Vite をバックグラウンドで起動する（`node_modules` がなければ `npm ci` を先に行う）

起動済みのものは起動し直さないので、何度実行してもよい。

## 起動後

- 画面: http://localhost:5173
- API: http://localhost:3000（`/api` は Vite の proxy 経由で届くため、ブラウザからは 5173 だけを見ればよい）
- Vite のログ: `frontend/vite.log`

## 止めるとき

```
docker compose stop          # DB・API（データは名前付きボリュームに残る）
```

Vite は `5173` を使っているプロセスを終了する。Windows なら次で止められる。

```
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 5173 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"
```
`docker compose down -v` はデータを消すので、ユーザーに頼まれない限り実行しない。

## うまくいかないとき

- GET が 204（本文なし）を返し、ログに `No template found ... rendering head :no_content` が出る: 起動中の API が、あとから追加したビュー（`app/views/**/*.jbuilder`）を検知できていない。Windows のバインドマウントでは Rails のファイル変更検知が効かないことがある。`docker compose restart api` で直る。実装の不具合ではない。
- `.env` が古い: `.env.example` と見比べる。
- API が上がらない: `docker compose logs api`。
- 3306 / 3000 / 5173 が他のプロセスに使われている: 使っているプロセスを止める。
