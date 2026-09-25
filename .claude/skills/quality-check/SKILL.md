---
name: quality-check
description: CI と同じ検査（RuboCop・Brakeman・bundler-audit・RSpec・ESLint・Prettier・vue-tsc・npm audit）をローカルで一括実行し、設計書と実装のずれを突き合わせる。「品質チェック」「PR を出す前の確認」「設計書と合っているか確認」のときに使う
---

# quality-check

手順7の品質監査で使う。次の 2 つからなる。

1. **ツールの一括実行**: CI が落ちる状態を、push の前に見つける
2. **設計書との突き合わせ**: [N-18](../../../docs/non-functional.md#保守性運用) の「差異が 0 件」を確認する

## 1. ツールの一括実行

```
bash .claude/skills/quality-check/run.sh
```

DB と API のコンテナが起動している必要がある（なければ `start-servers` を先に実行する）。

| 検査 | 内容 | 対応する要件 |
| --- | --- | --- |
| RuboCop | Ruby の書式（`rubocop-rails-omakase`） | N-34 |
| Brakeman | Ruby の静的セキュリティ解析 | N-35 |
| bundler-audit | gem の脆弱性 | N-35 |
| RSpec | リクエストスペック。テスト用 DB（`kakeibo_test`）に向けて実行する | N-16 |
| ESLint / Prettier / vue-tsc | フロントの検出・書式・型 | N-34 |
| npm audit | `--audit-level=high` | N-35 |

1 つ落ちても残りは実行し、最後に PASS / FAIL の一覧を出す。1 つでも FAIL なら終了コードは 1。

- **RSpec は開発 DB に向けない。** スクリプトは `DATABASE_URL` の DB 名を `_test` に差し替えて実行する。手で実行するときも同じにする（`spec/rails_helper.rb` が `*_test` 以外では中断する）
- 落ちたものは、出力を読んで原因を直す。CI の設定（`.github/workflows/ci.yml`）とこのスクリプトがずれていたら、スクリプトを CI に合わせる

## 2. 設計書との突き合わせ

**設計書が正。** ずれを見つけたら、まず「実装を直すのか、設計を変えるのか」を判断する。原則は実装を直す。設計を変えると判断したときだけ、**先に設計書を更新してから実装する**。黙って `docs/` を書き換えない。

### 何を何と比べるか

| 設計書 | 比べる相手 |
| --- | --- |
| `docs/features.md` の API 仕様（パス・メソッド・リクエスト・レスポンス・ステータス） | `backend/config/routes.rb`、`app/controllers/api/`、`app/views/api/**/*.jbuilder` と、実際に返る JSON |
| `docs/features.md` のバリデーション規則・エラーメッセージ | `app/models/`、コントローラの事前検証、フロントの `src/utils/validation.ts` |
| `docs/features.md` の受け入れ条件（F-01〜F-09） | `spec/requests/`。**受け入れ条件 1 つにつき `it` が 1 つ以上あるか** |
| `docs/database.md` のテーブル・インデックス・制約 | `db/schema.rb` |
| `docs/screens.md` の画面要素・遷移（S-01〜S-04） | `frontend/src/components/`、`App.vue`。実際にブラウザで操作して確認する |
| `docs/non-functional.md`（N-01〜N-40）の各「確認方法」 | 確認方法に書かれたとおりに実行する |
| `CLAUDE.md` の「実装上の注意」 | 該当するコード（`update_all` の事前検証、`delete_all`、月の範囲比較、SQL 集計、残額の計算など） |

### 進め方

1. 対象の設計書を上から読み、**確認できる 1 項目ずつ**、実装側の該当箇所か実行結果を確かめる。読んだだけで「合っている」と判断しない。API は `curl` で実際に叩く
2. ずれを見つけたら、表にして記録する（項目 / 設計書の記述 / 実装の状態 / 判断: 実装を直す or 設計を変える）
3. 実装を直すものは、Issue を立てて 1 件 = 1 PR で直す。修正のテストは、設計書の記述をそのままリクエストスペックの `it` に落とす
4. 設計を変えるものは、なぜ実装ではなく設計を変えるのかを書いてから、設計書を先に更新する
5. 最後に、全項目を確認し直して差異が 0 件であることを示す（[N-18](../../../docs/non-functional.md#保守性運用)）

### 注意

- 実装で決めたのに設計書にない判断が出たら、PR 本文だけでなく `docs/` にも書く
- 「やらないこと」（`CLAUDE.md`）に該当する機能は、気を利かせて追加しない
