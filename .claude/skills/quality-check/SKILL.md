---
name: quality-check
description: CI と同じ検査（RuboCop・Brakeman・bundler-audit・RSpec・ESLint・Prettier・vue-tsc・npm audit）をローカルで一括実行する。「品質チェック」「PR を出す前の確認」「CI が通るか見て」のときに使う
---

# quality-check

CI が落ちる状態を、push の前に見つける。ローカルで全部 PASS なら CI も緑になる、という状態を保つ。

**設計書と実装のずれの確認は、このスキルの役目ではない。** `design-audit` を使う（先にこのスキルを実行して、全部 PASS にしておく）。

## 使い方

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
