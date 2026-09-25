# 実装計画

[tech-stack.md](./tech-stack.md) の構成で、[features.md](./features.md) の機能を作り切るまでの段取り。
6 つのフェーズに分け、**前のフェーズの完了条件を満たしてから次へ進む**。

| フェーズ | 内容 | Issue 数の目安 |
| --- | --- | --- |
| [1](#フェーズ1-初期化) | 初期化 | 1 |
| [2](#フェーズ2-db) | DB | 1 |
| [3](#フェーズ3-api) | API | 7（F-01〜F-07） |
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
| 3 | `Category` モデル（`has_many :entries`、`type` の enum とバリデーション） | 同上 |
| 4 | `Entry` モデル（`belongs_to :category`、各項目のバリデーション） | [features.md のバリデーション規則](./features.md#バリデーション規則) |
| 5 | カテゴリの初期データを seed に書く | [database.md の初期データ](./database.md#初期データcategories-のシード) |
| 6 | モデルのバリデーションをテストする | - |

### 注意点

- `type` は ActiveRecord が**単一テーブル継承（STI）用に予約している列名**のため、`Category` モデル側で STI を無効化する設定が必要になる。回避できない場合は列名を `category_type` に変更し、[database.md](./database.md) を更新する
- `amount` のチェック制約（`> 0 かつ <= 9999999`）は、DB 制約とモデルバリデーションの両方に入れる

### 完了条件

- `rails db:migrate` が通り、`schema.rb` が [database.md](./database.md) の定義と一致する
- `rails db:seed` で 13 件のカテゴリが投入され、再実行しても重複しない
- モデルのバリデーションのテストが緑（不正な金額・日付なし・メモ201文字などが弾かれる）

---

## フェーズ3: API

[features.md](./features.md) の F-01〜F-07 を実装する。**1 機能 = 1 Issue = 1 PR**。
各 PR では、受け入れ条件をそのままリクエストスペックの `it` に落としてから実装する。

| Issue | 対応機能 | エンドポイント |
| --- | --- | --- |
| 一覧取得API | [F-01](./features.md#f-01-一覧表示) | `GET /api/entries`、`GET /api/categories` |
| 検索API | [F-03](./features.md#f-03-検索絞り込み) | `GET /api/entries?from&to&category_id&keyword` |
| 追加API | [F-04](./features.md#f-04-レコード追加) | `POST /api/entries` |
| 更新API | [F-05](./features.md#f-05-レコード更新と並び替えドラッグドロップ) | `PUT /api/entries/{id}` |
| 並び替えAPI | [F-05](./features.md#f-05-レコード更新と並び替えドラッグドロップ) | `PATCH /api/entries/order` |
| 一括更新API | [F-06](./features.md#f-06-一括更新) | `PATCH /api/entries/bulk` |
| 削除API | [F-07](./features.md#f-07-削除) | `DELETE /api/entries/{id}` |

F-02 は画面のみの機能のため、このフェーズには含めない（フェーズ4で扱う）。

### 最初の Issue で一緒に作るもの

一覧取得APIの PR で、以降すべての API が使う土台も作る。

- ルーティングの名前空間（`namespace :api`）
- エラーハンドリングの共通化（`rescue_from` で 400 / 404 / 500 を [features.md の形式](./features.md#エラーレスポンス)に整形）
- レスポンスの JSON 整形（Jbuilder のテンプレート、キーは snake_case）

### 完了条件

- 7 本すべてのエンドポイントが実装され、リクエストスペックが緑
- 各機能の受け入れ条件が、漏れなく `it` として存在する
- 一括更新（F-06）で、対象外 ID が 1 件でも含まれる場合に**何も更新されない**ことがテストで確認できている
- 並び替え（F-05）が 1 リクエスト・1 トランザクションで完結している

---

## フェーズ4: 画面

[screens.md](./screens.md) の画面を Vue で実装する。**この段階では API に繋がず、ダミーデータで組む**。
[mockups/](./mockups/) の HTML と CSS をそのまま流用し、見た目を作り直さない。

| Issue | 内容 | 対応 |
| --- | --- | --- |
| 一覧画面の実装 | ヘッダ・集計バー・テーブル・空表示・ローディング | [F-02](./features.md#f-02-一覧画面ui) / [S-01](./screens.md#s-01-一覧画面) |
| 入力モーダルの実装 | 追加・編集で共用、項目ごとのエラー表示領域 | [S-02](./screens.md#s-02-追加編集モーダル) |
| 検索バーと一括操作バーの実装 | 検索条件の保持、選択状態の保持、選択時のみ一括操作バーを表示 | [S-01](./screens.md#s-01-一覧画面) / [S-03](./screens.md#s-03-削除確認ダイアログ) |

### 先に決めること

- `Entry` / `Category` の TypeScript 型定義（[features.md のJSON表現](./features.md#レコードの-json-表現)と一致させる）
- コンポーネント分割（`EntryTable` / `EntryRow` / `EntryFormModal` / `SearchBar` / `BulkActionBar` / `ConfirmDialog` / `SummaryBar`）
- 金額の 3 桁区切り表示と、収入 `+` / 支出 `-` の表示を担う共通関数

### 完了条件

- ダミーデータで、モックアップと同等の見た目になっている
- 追加ボタンでモーダルが開閉する
- 行のチェックボックスで選択でき、1 件以上選択すると一括操作バーが現れる
- 金額が 3 桁区切りで、収入・支出が色で区別できる

---

## フェーズ5: 結合

画面と API を繋ぎ、アプリとして動く状態にする。

| Issue | 内容 |
| --- | --- |
| API接続と CRUD の結合 | `src/api/` に fetch のラッパを作り、一覧・検索・追加・更新・一括更新・削除を実際の API に繋ぐ。エラーレスポンスの表示（項目エラーは入力欄の下、それ以外はエラーバナー）も行う |
| ドラッグ&ドロップの結合 | vuedraggable を導入し、並び替え結果を `PATCH /api/entries/order` で永続化する。検索中は無効化し、API 失敗時は並びを元に戻す |

### 完了条件

- [features.md](./features.md) の F-01〜F-07 の受け入れ条件を、ブラウザ上で手動で一通り確認できる
- 追加 → 一覧反映 → 検索 → 一括更新 → 並び替え → リロードして順序が保たれる → 削除、が通しで動く
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
| 4 | デプロイと動作確認 | `deploy.sh`（フロントのビルドと S3 同期、EC2 上のコンテナ更新、`db:migrate` の実行）、本番環境変数（`DATABASE_URL`、`ALLOWED_ORIGINS`）の設定 |

### 注意点

- 本番は S3 と EC2 でオリジンが異なるため、`rack-cors` の設定が必須になる。ここを忘れると画面は表示されるが API が全滅する
- 機密値（RDS パスワード）は `.tfvars` に置き、Git にコミットしない
- 検証が終わったら `terraform destroy` で撤去する（手順9）

### 完了条件

- S3 の公開 URL を開くと画面が表示される
- 公開環境で F-01〜F-07 のすべてが動作する
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
