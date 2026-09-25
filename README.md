# kakeibo-app-1

**決めた予算の範囲内で生活できているかを、一目で把握できる家計簿アプリ。**

記録を溜めることが目的ではなく、「**あといくら使えるか**」に答えることを中心に据えている。月の予算を決め、支払いを記録し、残額を見る。画面で最も大きく表示されるのは残額。

初級者最終課題として、要件定義からデプロイまでの一連の開発プロセスを実践する。

## 想定する使い方

```
① 月の予算を決めて登録する    →「9月は80,000円まで」
② 支払いのたびに記録する      →「9/25 食費 1,280円」
③ 残額を確認する              →「残り27,700円」 ★最重要
④ 内訳を見て使いすぎに気づく  →「食費が32,100円…多いな」
```

## 技術構成

| 層 | 技術 |
| --- | --- |
| バックエンド | Ruby 3.3 / Ruby on Rails 8.1（APIモード） |
| フロントエンド | TypeScript / Vue 3（Composition API）/ Vite |
| データベース | MySQL 8.4 |
| テスト | RSpec + FactoryBot（リクエストスペック） |
| ローカル実行 | Docker Compose |
| インフラ | Terraform + AWS（EC2 / RDS / S3） |

選定の理由は [docs/tech-stack.md](./docs/tech-stack.md) に記載している。

## ドキュメント

**`docs/` の設計書を正とする。** 実装が設計書と異なる場合は実装側を直す。設計を変える判断をしたときだけ、設計書の更新を先行させる（[N-18](./docs/non-functional.md#保守性運用)）。

| ドキュメント | 答えている問い |
| --- | --- |
| [requirements.md](./docs/requirements.md) | なぜ作るのか。何を作り、何を作らないか |
| [features.md](./docs/features.md) | 機能ごとに、どう動けば完成と言えるか（F-01〜F-09、API 仕様） |
| [screens.md](./docs/screens.md) | 画面に何が表示され、どう遷移するか（S-01〜S-04） |
| [database.md](./docs/database.md) | データをどう保存するか（ER 図、テーブル定義） |
| [non-functional.md](./docs/non-functional.md) | 速度・安全性など機能以外の条件（N-01〜N-40） |
| [tech-stack.md](./docs/tech-stack.md) | どの技術を、なぜ選んだか |
| [plan.md](./docs/plan.md) | どの順番で作るか（6 フェーズ） |
| [proposal.md](./docs/proposal.md) | 顧客への説明資料 |

はじめて読む場合は [requirements.md](./docs/requirements.md) から。目的とスコープが分かると、他のドキュメントの判断理由が追える。

画面のイメージは [docs/mockups/index.html](./docs/mockups/index.html) をブラウザで開くと確認できる（静的 HTML、ビルド不要）。

## 開発の進め方

作業は GitHub Issue 単位に分割し、PR 経由で main に取り込む。main への直接 push はしない。
詳細は [CONTRIBUTING.md](./CONTRIBUTING.md) を参照。

## リポジトリ構成

```
backend/    Rails API
frontend/   Vue + Vite
infra/      Terraform
docs/       設計書（正）
```

## ローカル環境の構築

必要なツールは Docker Desktop と Node.js 20 以上。Ruby はコンテナ側で動かすため、ホストへの導入は不要。

```
cp .env.example .env              # DB の接続情報。.env は Git にコミットしない
docker compose up                 # MySQL（3306）と Rails API（3000）
cd frontend && npm ci && npm run dev   # Vite（5173）
```

ブラウザで http://localhost:5173 を開く。`/api` へのリクエストは Vite の proxy で Rails（3000）に転送されるため、開発中に CORS は発生しない。

| 対象 | コマンド | 実行場所 |
| --- | --- | --- |
| Ruby の書式 | `bin/rubocop` | `backend/`（コンテナ内） |
| Ruby の静的セキュリティ解析 | `bin/brakeman` | 同上 |
| gem の脆弱性 | `bin/bundler-audit` | 同上 |
| テスト | `bundle exec rspec` | 同上 |
| フロントの検出・書式・型 | `npm run lint` / `npm run format:check` / `npm run typecheck` | `frontend/` |

## 現在の状況

設計フェーズが完了し、実装はこれから。進捗は [plan.md](./docs/plan.md) の 6 フェーズに対応する。
