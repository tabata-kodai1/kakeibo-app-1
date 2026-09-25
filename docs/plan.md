# 実装計画

[tech-stack.md](./tech-stack.md) の構成で、[features.md](./features.md) の機能を作り切るまでの段取り。
6 つのフェーズに分け、**前のフェーズの完了条件を満たしてから次へ進む**。

| フェーズ | 内容 | Issue 数の目安 |
| --- | --- | --- |
| [1](#フェーズ1-初期化) | 初期化 | 1 |
| [2](#フェーズ2-db) | DB | 1 |
| [3](#フェーズ3-api) | API | 7 |
| [4](#フェーズ4-画面) | 画面 | 3 |
| [5](#フェーズ5-結合) | 結合 | 2 |
| [6](#フェーズ6-aws) | AWS | 4 |

フェーズ3以降は **1 Issue = 1 ブランチ = 1 PR** で進める（手順4で整備する運用ルールに従う）。
ブランチ名は `feature/<Issue番号>-<概要>`、PR 本文に `Closes #<Issue番号>` を書く。

---

## フェーズ1: 初期化

土台を用意する。この時点では機能を作らない。

### やること

| # | 作業 | 成果物 |
| --- | --- | --- |
| 1 | リポジトリ構成を決める | `backend/`、`frontend/`、`infra/`、`docs/` |
| 2 | Docker Compose で PostgreSQL 16 を起動できるようにする | `docker-compose.yml` |
| 3 | Rails を API モードで初期化する | `backend/`（`rails new --api --database=postgresql`） |
| 4 | RSpec と FactoryBot を導入する | `backend/spec/`、`.rspec` |
| 5 | Vite + Vue 3 + TypeScript を初期化する | `frontend/` |
| 6 | Vite の proxy で `/api` を Rails に転送する設定を入れる | `frontend/vite.config.ts` |
| 7 | `.gitignore` を整える | `master.key`、`.env`、`node_modules`、`*.tfvars` を除外 |

### 完了条件

- `docker compose up` で PostgreSQL が起動し、Rails から接続できる
- Rails が `localhost:3000` で起動し、疎通確認用のエンドポイントが JSON を返す
- Vite が `localhost:5173` で起動し、ブラウザから Vue の初期画面が見える
- フロントから `/api/...` を叩くと proxy 経由で Rails に届く（CORS エラーが出ない）
- `bundle exec rspec` がエラーなく実行できる（テストは 0 件でよい）

---

## フェーズ2: DB

[database.md](./database.md) の設計をスキーマとして作る。

### やること

| # | 作業 | 対応するdocs |
| --- | --- | --- |
| 1 | `categories` テーブルのマイグレーション | [database.md](./database.md#categoriesカテゴリ) |
| 2 | `entries` テーブルのマイグレーション（外部キー・チェック制約・インデックス含む） | [database.md](./database.md#entries収支レコード) |
| 3 | `budgets` テーブルのマイグレーション（`year_month` の一意制約含む） | [database.md](./database.md#budgets月次予算) |
| 4 | `Category` モデル（`has_many :entries`、`type` のバリデーション） | 同上 |
| 5 | `Entry` モデル（`belongs_to :category`、各項目のバリデーション） | [features.md のバリデーション規則](./features.md#バリデーション規則) |
| 6 | `Budget` モデル（`year_month` の形式と一意性のバリデーション） | 同上 |
| 7 | カテゴリの初期データを seed に書く | [database.md の初期データ](./database.md#初期データcategories-のシード) |
| 8 | モデルのバリデーションをテストする | - |

### 注意点

- `type` は ActiveRecord が**単一テーブル継承（STI）用に予約している列名**のため、`Category` モデル側で STI を無効化する設定が必要になる。回避できない場合は列名を `category_type` に変更し、[database.md](./database.md) を更新する
- `amount` のチェック制約は、DB 制約とモデルバリデーションの両方に入れる
- `budgets.year_month` の一意制約は、DB 側にも必ず入れる（[F-02](./features.md#f-02-予算の設定) の「2回目は上書きされる」を保証する土台になる）

### 完了条件

- `rails db:migrate` が通り、`schema.rb` が [database.md](./database.md) の定義と一致する
- `rails db:seed` で 13 件のカテゴリが投入され、再実行しても重複しない
- モデルのバリデーションのテストが緑（不正な金額・日付なし・メモ201文字・同月の予算重複などが弾かれる）

---

## フェーズ3: API

[features.md](./features.md) の機能を実装する。**1 機能 = 1 Issue = 1 PR**。
各 PR では、受け入れ条件をそのままリクエストスペックの `it` に落としてから実装する。

| Issue | 対応機能 | エンドポイント |
| --- | --- | --- |
| 明細一覧API | [F-04](./features.md#f-04-月別明細一覧) | `GET /api/entries?month=`、`GET /api/categories` |
| 月次サマリーAPI | [F-01](./features.md#f-01-月次サマリー), [F-03](./features.md#f-03-カテゴリ別集計) | `GET /api/summary?month=` |
| 予算設定API | [F-02](./features.md#f-02-予算の設定) | `PUT /api/budgets/{year_month}` |
| 検索API | [F-08](./features.md#f-08-検索絞り込み) | `GET /api/entries?category_id=&keyword=&from=&to=` |
| 追加API | [F-05](./features.md#f-05-収支の追加) | `POST /api/entries` |
| 更新・削除API | [F-06](./features.md#f-06-収支の編集), [F-07](./features.md#f-07-収支の削除) | `PUT /api/entries/{id}`、`DELETE /api/entries/{id}` |
| 一括更新API | [F-09](./features.md#f-09-一括更新) | `PATCH /api/entries/bulk` |

明細一覧APIを最初にするのは、他のすべての API が `entries` の取得を前提にするため。
月次サマリーAPIを 2 番目にするのは、これがアプリの中心機能（[F-01](./features.md#f-01-月次サマリー)）であり、早い段階で形にしておきたいため。

### 最初の Issue で一緒に作るもの

明細一覧APIの PR で、以降すべての API が使う土台も作る。

- ルーティングの名前空間（`namespace :api`）
- エラーハンドリングの共通化（`rescue_from` で 400 / 404 / 500 を [features.md の形式](./features.md#エラーレスポンス)に整形）
- レスポンスの JSON 整形（Jbuilder のテンプレート、キーは snake_case）
- 月の絞り込みの共通化（[database.md の方針](./database.md#月の絞り込み方法)どおり、範囲比較で書く）

### 完了条件

- すべてのエンドポイントが実装され、リクエストスペックが緑
- 各機能の受け入れ条件が、漏れなく `it` として存在する
- 月次サマリーで、予算未設定の月が `null` を返しエラーにならないことがテストで確認できている
- 一括更新（F-09）で、対象外 ID が 1 件でも含まれる場合に**何も更新されない**ことがテストで確認できている
- 月をまたいだデータが集計に混ざらないことがテストで確認できている

---

## フェーズ4: 画面

[screens.md](./screens.md) の画面を Vue で実装する。**この段階では API に繋がず、ダミーデータで組む**。
[mockups/](./mockups/) の HTML と CSS をそのまま流用し、見た目を作り直さない。

| Issue | 内容 | 対応 |
| --- | --- | --- |
| サマリーと内訳の実装 | 月切替・予算・使用額・残額・進捗バー・カテゴリ別内訳 | [F-01](./features.md#f-01-月次サマリー), [F-03](./features.md#f-03-カテゴリ別集計) / [S-01](./screens.md#s-01-ダッシュボード) |
| 明細一覧と検索バーの実装 | テーブル・空表示・ローディング・検索条件の保持 | [F-04](./features.md#f-04-月別明細一覧), [F-08](./features.md#f-08-検索絞り込み) / [S-01](./screens.md#s-01-ダッシュボード) |
| モーダルと選択モードの実装 | 収支入力・予算設定・削除確認の各モーダル、選択モードの切り替え | [S-02](./screens.md#s-02-収支入力モーダル), [S-03](./screens.md#s-03-削除確認ダイアログ), [S-04](./screens.md#s-04-予算設定モーダル) |

### 先に決めること

- `Entry` / `Category` / `Summary` / `Budget` の TypeScript 型定義（[features.md のJSON表現](./features.md#レコードの-json-表現)と一致させる）
- コンポーネント分割（`MonthNav` / `SummaryPanel` / `CategoryBreakdown` / `SearchBar` / `EntryTable` / `EntryRow` / `BulkActionBar` / `EntryFormModal` / `BudgetModal` / `ConfirmDialog`）
- 金額の 3 桁区切り表示と、収入 `+` / 支出 `-` の表示を担う共通関数

### 完了条件

- ダミーデータで、モックアップと同等の見た目になっている
- **残額が画面内で最も目立つ要素になっている**
- 予算超過時に、残額と進捗バーが警告色になる
- 月切替ボタンで対象月の表示が変わる
- 「選択」ボタンで選択モードに入り、「完了」で戻る
- 各モーダルが開閉する

---

## フェーズ5: 結合

画面と API を繋ぎ、アプリとして動く状態にする。

| Issue | 内容 |
| --- | --- |
| サマリー・明細の結合 | `src/api/` に fetch のラッパを作り、月次サマリー・明細一覧・月切替・検索を実際の API に繋ぐ。エラーレスポンスの表示（項目エラーは入力欄の下、それ以外はエラーバナー）も行う |
| 更新系の結合 | 追加・編集・削除・予算設定・一括更新を API に繋ぐ。**更新のたびにサマリーと内訳を再取得**し、残額が即座に反映されるようにする |

### 完了条件

- [features.md](./features.md) の F-01〜F-09 の受け入れ条件を、ブラウザ上で手動で一通り確認できる
- 予算設定 → 支出を追加 → 残額が減る → 削除 → 残額が戻る、が通しで動く
- 月を切り替えると、サマリー・内訳・明細がすべて連動して変わる
- 絞り込み中でも、サマリーと内訳が対象月全体の値のままであること
- バリデーションエラー時に、該当項目の下にメッセージが出る
- API を止めた状態でエラーバナーが出る

---

## フェーズ6: AWS

Terraform でインフラを構築し、デプロイする。

| # | Issue | 内容 |
| --- | --- | --- |
| 1 | tfstate 用 S3 の bootstrap | state 保管用のバケットを先に作る（このバケット自身は state 管理の対象外とする） |
| 2 | ネットワークと RDS | VPC、サブネット、セキュリティグループ、RDS（PostgreSQL 16）。RDS はプライベートに置き、EC2 のSGからのみ許可 |
| 3 | EC2 と S3（フロント用） | EC2（Docker で Rails を実行）、フロント配信用の S3 バケットと静的ウェブサイト設定 |
| 4 | デプロイと動作確認 | `deploy.sh`（フロントのビルドと S3 同期、EC2 上のコンテナ更新、`db:migrate` と `db:seed` の実行）、本番環境変数（`DATABASE_URL`、`ALLOWED_ORIGINS`）の設定 |

### 注意点

- 本番は S3 と EC2 でオリジンが異なるため、`rack-cors` の設定が必須になる。ここを忘れると画面は表示されるが API が全滅する
- 機密値（RDS パスワード）は `.tfvars` に置き、Git にコミットしない
- EC2 と RDS は**起動している時間だけ課金**される。検証が終わったら `terraform destroy` で撤去する（手順9）

### 完了条件

- S3 の公開 URL を開くと画面が表示される
- 公開環境で F-01〜F-09 のすべてが動作する
- `terraform destroy` で全リソースが削除できることを確認している（実行は課題の完了後）

---

## このあとの手順との対応

| 手順 | このドキュメントとの関係 |
| --- | --- |
| 手順4（GitHub運用ルール） | フェーズ1の前に実施する。`CLAUDE.md`、`CONTRIBUTING.md`、Issue/PRテンプレート、main 保護 |
| 手順5（土台づくり） | フェーズ1に相当 |
| 手順6（機能実装） | フェーズ3〜5に相当 |
| 手順7（スキルと品質監査） | フェーズ5の完了後。`start-servers`、`quality-check` を用意し、docs と実装のずれを直す |
| 手順8（AWS） | フェーズ6に相当 |
| 手順9（仕上げ） | レビュー指摘の修正、`terraform destroy` |
