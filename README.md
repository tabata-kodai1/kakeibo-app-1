# kakeibo-app-1

**決めた予算の範囲内で生活できているかを、一目で把握できる家計簿アプリ。**

記録を溜めることが目的ではなく、「**あといくら使えるか**」に答えることを中心に据えている。月の予算を決め、支払いを記録し、残額を見る。画面で最も大きく表示されるのは残額。

初級者最終課題として、要件定義からデプロイまでの一連の開発プロセスを実践した。設計・実装・AWS へのデプロイまで完了している。

## 想定する使い方

```
① 月の予算を決めて登録する    →「9月は80,000円まで」
② 支払いのたびに記録する      →「9/25 食費 1,280円」
③ 残額を確認する              →「残り27,700円」 ★最重要
④ 内訳を見て使いすぎに気づく  →「食費が32,100円…多いな」
```

## 機能

画面は 1 枚のダッシュボード（S-01）と 3 つのモーダル（S-02〜S-04）で構成する。認証はなく、利用者は 1 名を前提とする。

| ID | 機能 | 要点 |
| --- | --- | --- |
| F-01 | 月次サマリー | 予算・支出・残額・使用率。**残額を最も大きく表示する** |
| F-02 | 予算の設定 | 月ごとに 1 件。予算 0 円と予算未設定は別の状態として扱う |
| F-03 | カテゴリ別集計 | 支出をカテゴリ別に集計し、金額の大きい順に並べる |
| F-04 | 月別明細一覧 | 月を切り替えて明細を見る。1 か月あたり 500 件まで |
| F-05 | 収支の追加 | 日付・カテゴリ・金額・メモ |
| F-06 | 収支の編集 | 収支区分をまたぐカテゴリ変更は禁止 |
| F-07 | 収支の削除 | 確認ダイアログを経て物理削除する |
| F-08 | 検索・絞り込み | 期間・カテゴリ・キーワード。絞り込み中もサマリーは月全体のまま |
| F-09 | 一括更新・一括削除 | 選択した明細のカテゴリ・日付をまとめて変更、または削除 |

仕様の詳細と受け入れ条件は [features.md](./docs/features.md) にある。API は次の 9 本。

| メソッド | パス | 用途 |
| --- | --- | --- |
| GET | `/api/summary?month=YYYY-MM` | 月次サマリーとカテゴリ別内訳 |
| GET | `/api/entries` | 明細一覧（月指定・検索条件つき） |
| POST | `/api/entries` | 追加 |
| PUT | `/api/entries/{id}` | 更新 |
| DELETE | `/api/entries/{id}` | 削除 |
| PATCH | `/api/entries/bulk` | 一括更新 |
| DELETE | `/api/entries/bulk` | 一括削除 |
| PUT | `/api/budgets/{year_month}` | 予算の登録・更新 |
| GET | `/api/categories` | カテゴリ一覧（13 件、固定） |

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

Claude Code を使う場合は、上の 3 手順を `start-servers` スキル（`bash .claude/skills/start-servers/start.sh`）で 1 コマンドにまとめて実行できる（[N-36](./docs/non-functional.md#開発プロセス品質)）。

ブラウザで http://localhost:5173 を開く。`/api` へのリクエストは Vite の proxy で Rails（3000）に転送されるため、開発中に CORS は発生しない。

| 対象 | コマンド | 実行場所 |
| --- | --- | --- |
| Ruby の書式 | `bin/rubocop` | `backend/`（コンテナ内） |
| Ruby の静的セキュリティ解析 | `bin/brakeman` | 同上 |
| gem の脆弱性 | `bin/bundler-audit` | 同上 |
| テスト | `bundle exec rspec` | 同上 |
| フロントの検出・書式・型 | `npm run lint` / `npm run format:check` / `npm run typecheck` | `frontend/` |
| フロントの依存の脆弱性 | `npm audit --audit-level=high` | `frontend/` |

上の検査は PR ごとに CI（[.github/workflows/ci.yml](./.github/workflows/ci.yml)）で実行し、緑でなければマージできない（[N-33](./docs/non-functional.md#開発プロセス品質)〜[N-35](./docs/non-functional.md#開発プロセス品質)）。Claude Code を使う場合は `quality-check` スキル（`bash .claude/skills/quality-check/run.sh`）で同じものを一括実行できる。

テスト対象は API のリクエストスペック。フロントエンドは手動確認とし、画面の挙動は `design-audit` スキルの `browser-check.sh`（隔離環境で Chrome を操作、98 項目）で確かめる。これは監査の道具で、CI の検査には入れていない。

## 本番環境（AWS）

インフラは Terraform でコード化してある（`infra/`）。`terraform apply` で構築し、`terraform destroy` で撤去できる（[N-17](./docs/non-functional.md#保守性運用)）。

```
ブラウザ ──HTML/JS/CSS──> S3（静的ウェブサイト）
        ──/api/* JSON──> EC2（Rails を Docker で実行）──> RDS（MySQL 8.4、プライベートサブネット）
```

| リソース | 役割 |
| --- | --- |
| S3（フロント用） | `vite build` の成果物を静的配信。バケットポリシーで接続元 IP を制限 |
| S3（tfstate 用） | Terraform の state 保管。他より先に `infra/bootstrap/` で作る |
| EC2 | Rails API を Docker で実行。Elastic IP で IP を固定 |
| RDS（MySQL） | データ永続化。プライベートサブネットに置き、EC2 のセキュリティグループからのみ接続を許可 |

**認証がない代わりに、接続元 IP で守る。** セキュリティグループは S3 に効かないため、API（EC2）と画面（S3）の両方に制限が必要になる（[N-08](./docs/non-functional.md#セキュリティ)）。通信は HTTP のみで、HTTPS は対象外とした（理由は [non-functional.md](./docs/non-functional.md#対象外とする非機能要件)）。

### デプロイ

自動デプロイ（CD）は採用せず、手動で実行する。

```
terraform -chdir=infra apply    # 初回、または撤去後に作り直すとき
bash deploy.sh                  # フロントと API を本番に反映する
bash deploy.sh --dry-run        # 実行せず、手順だけを表示する（AWS に触れない）
```

`deploy.sh` は、フロントのビルドと S3 同期（`Cache-Control` を出し分ける）、EC2 上でのイメージビルドとコンテナ入れ替え、`db:migrate` と `db:seed`、疎通と CORS の確認までを行う。DB パスワードと `master.key` は標準入力で渡し、コマンドライン引数やファイルとして EC2 に残さない。

秘密情報（`infra/terraform.tfvars`、`infra/backend.hcl`、`backend/config/master.key`、SSH の秘密鍵）は Git 管理外のため、**これらが手元にないとデプロイできない**。この PC の外にも控えを持つ。

**EC2 と RDS は起動している時間だけ課金される。** 検証が終わったら `terraform destroy` で撤去する（[N-20](./docs/non-functional.md#保守性運用)）。撤去すると DB のデータは残らない（最終スナップショットを取らない設定にしてある）。

## 現在の状況

[plan.md](./docs/plan.md) の 6 フェーズすべてが完了している。設計 → 実装 → AWS へのデプロイまでを通し、公開環境で F-01〜F-09 の動作を確認した。費用を止めるため、AWS のリソースは `terraform destroy` で撤去済み。作り直す場合は上の「デプロイ」の手順を実行する。
