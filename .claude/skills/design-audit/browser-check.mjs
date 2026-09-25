import { chromium } from 'playwright-core'
import { execSync } from 'node:child_process'
import { tmpdir } from 'node:os'

// フェーズ5の完了条件・S-01〜S-04・N-02・N-21〜N-26 を、Chrome で実際に操作して確認する。
// 直接は実行せず、browser-check.sh から使う（隔離環境の起動と片付けをそちらが行う）。
// 隔離環境の DB（kakeibo_e2e）だけを操作する。開発用の DB・サーバーには触れない。
const UI = process.env.UI_URL ?? 'http://localhost:5174'
const API = process.env.API_URL ?? 'http://localhost:3001'
const ROOT = process.env.REPO_ROOT ?? process.cwd()
const SHOTS = process.env.SHOTS_DIR ?? tmpdir()

const now = new Date()
const pad = (n) => String(n).padStart(2, '0')
const month = `${now.getFullYear()}-${pad(now.getMonth() + 1)}`
const today = `${month}-${pad(now.getDate())}`
const monthLabel = `${now.getFullYear()}年${now.getMonth() + 1}月`
const nextMonthDate = new Date(now.getFullYear(), now.getMonth() + 1, 1)
const nextMonth = `${nextMonthDate.getFullYear()}-${pad(nextMonthDate.getMonth() + 1)}`
const nextMonthLabel = `${nextMonthDate.getFullYear()}年${nextMonthDate.getMonth() + 1}月`

const results = []
function check(name, ok, detail = '') {
  results.push({ name, ok, detail })
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `   ← ${detail}`}`)
}

function resetDb() {
  execSync(`docker compose exec -T db mysql -uroot -pkakeibo kakeibo_e2e -e "DELETE FROM entries; DELETE FROM budgets"`, { cwd: ROOT, stdio: 'ignore' })
}
async function api(method, path, body) {
  const res = await fetch(`${API}${path}`, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined })
  return res.status === 204 ? null : res.json()
}
const cats = Object.fromEntries((await api('GET', '/api/categories')).map((c) => [`${c.category_type}:${c.name}`, c.id]))
const food = cats['EXPENSE:食費']
const daily = cats['EXPENSE:日用品']
const salary = cats['INCOME:給与']
const mkEntry = (entry_date, category_id, amount, memo = null) => api('POST', '/api/entries', { entry_date, category_id, amount, memo })

const browser = await chromium.launch({ channel: 'chrome', headless: true })

async function fresh(opts = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, locale: 'ja-JP', timezoneId: 'Asia/Tokyo', ...opts })
  const page = await context.newPage()
  return { context, page }
}
const text = async (page, sel) => ((await page.locator(sel).first().innerText().catch(() => '')) || '').replace(/\s+/g, ' ').trim()
const open = async (page) => { await page.goto(UI); await page.locator('.remaining').waitFor() ; await page.locator('.month-nav .current').waitFor() }
const dlg = (page) => page.locator('dialog[open]')

try {
  // ---------- S1: 通し（予算設定 → 追加 → 残額が減る → 削除 → 戻る）
  resetDb()
  {
    const { context, page } = await fresh()
    await open(page)
    check('S1 初期表示: 対象月が当月で明示される', (await text(page, '.month-nav .current')) === monthLabel, await text(page, '.month-nav .current'))
    check('S1 予算未設定: 「未設定」と案内が出て、進捗バーは出ない', (await text(page, '.summary-head')).includes('未設定') && (await text(page, '.remaining')).includes('予算が未設定です') && (await page.locator('.progress').count()) === 0)
    check('S1 レコード 0 件: 「この月のデータがありません」', (await text(page, '.table-wrap .empty')) === 'この月のデータがありません')
    check('S1 支出 0 件: 「支出がありません」', (await text(page, '.card:has(.card-title)')).includes('支出がありません'))

    await page.getByRole('button', { name: '予算を設定' }).click()
    check('S1 予算モーダル: 未設定の月は入力欄が空', (await page.locator('#budget-amount').inputValue()) === '')
    check('S1 N-21 予算モーダル: 開いたとき最初の入力欄にフォーカス', await page.evaluate(() => document.activeElement?.id === 'budget-amount'), await page.evaluate(() => document.activeElement?.tagName + '#' + document.activeElement?.id))
    await page.locator('#budget-amount').fill('80000')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    await page.locator('dialog[open]').waitFor({ state: 'detached' }).catch(() => {})
    await page.waitForFunction(() => document.querySelector('.remaining .value')?.textContent?.includes('80,000'))
    check('S1 予算保存: 残額が即座に 80,000 になる', (await text(page, '.remaining .value')).includes('80,000'), await text(page, '.remaining .value'))
    check('S1 予算保存: モーダルが閉じる', (await dlg(page).count()) === 0)

    await page.getByRole('button', { name: '＋ 追加' }).click()
    check('S1 追加モーダル: 日付の初期値が本日（当月）', (await page.locator('#entry-date').inputValue()) === today, await page.locator('#entry-date').inputValue())
    check('S1 追加モーダル: カテゴリが「支出」「収入」でグループ分け', JSON.stringify(await page.locator('#entry-category optgroup').evaluateAll((els) => els.map((e) => e.label))) === JSON.stringify(['支出', '収入']))
    check('S1 N-21 追加モーダル: 最初の入力欄にフォーカス', await page.evaluate(() => document.activeElement?.id === 'entry-date'), await page.evaluate(() => document.activeElement?.id))
    await page.locator('#entry-category').selectOption({ label: '食費' })
    await page.locator('#entry-amount').fill('1280')
    await page.locator('#entry-memo').fill('スーパー')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    await page.waitForFunction(() => document.querySelector('.remaining .value')?.textContent?.includes('78,720'))
    check('S1 追加: 残額が 78,720 に減る', (await text(page, '.remaining .value')).includes('78,720'), await text(page, '.remaining .value'))
    check('S1 追加: 一覧に行が現れ、支出は - 付き 3 桁区切り', (await text(page, 'tbody tr')).includes('-1,280') && (await text(page, 'tbody tr')).includes('スーパー'), await text(page, 'tbody tr'))
    check('S1 追加: カテゴリ別内訳が更新される', (await text(page, '.breakdown-row')).includes('食費') && (await text(page, '.breakdown-row')).includes('100%'), await text(page, '.breakdown-row'))
    check('S1 追加: 件数表示「明細 1件」', (await text(page, '.list-head .count')) === '明細 1件', await text(page, '.list-head .count'))
    await page.screenshot({ path: `${SHOTS}/s1-main.png` })

    await page.locator('tbody tr').first().getByRole('button', { name: '削除' }).click()
    check('S1 削除確認: 見出し・本文', (await text(page, 'dialog[open] h2')) === '削除の確認' && (await text(page, 'dialog[open] .modal-body')).includes('このデータを削除します。') && (await text(page, 'dialog[open] .modal-body')).includes('この操作は取り消せません。'), await text(page, 'dialog[open] .modal-body'))
    check('S3 削除確認: 初期フォーカスは「キャンセル」', await page.evaluate(() => document.activeElement?.textContent?.trim() === 'キャンセル'), await page.evaluate(() => document.activeElement?.textContent))
    await dlg(page).getByRole('button', { name: 'キャンセル' }).click()
    check('S1 削除キャンセル: 何も削除されない', (await page.locator('tbody tr').count()) === 1)
    await page.locator('tbody tr').first().getByRole('button', { name: '削除' }).click()
    await dlg(page).getByRole('button', { name: '削除する' }).click()
    await page.waitForFunction(() => document.querySelector('.remaining .value')?.textContent?.includes('80,000'))
    check('S1 削除: 残額が 80,000 に戻る', (await text(page, '.remaining .value')).includes('80,000'), await text(page, '.remaining .value'))
    check('S1 削除: 一覧が空になる', (await text(page, '.table-wrap .empty')) === 'この月のデータがありません')
    await context.close()
  }

  // ---------- S2: 月切替の連動と、月ごとの独立
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  await mkEntry(today, food, 5000, '今月分')
  await mkEntry(`${nextMonth}-01`, daily, 700, '来月分')
  {
    const { context, page } = await fresh()
    await open(page)
    await page.getByRole('button', { name: '翌月 ▶' }).click()
    await page.waitForFunction((l) => document.querySelector('.month-nav .current')?.textContent === l, nextMonthLabel)
    await page.waitForFunction(() => document.querySelector('.summary-head')?.textContent?.includes('未設定'))
    check('S2 翌月へ: 対象月の表示が変わる', (await text(page, '.month-nav .current')) === nextMonthLabel)
    check('S2 翌月へ: 予算が月ごとに独立（翌月は未設定）', (await text(page, '.summary-head')).includes('未設定'))
    check('S2 翌月へ: 明細が翌月のものに変わる', (await text(page, 'tbody')).includes('来月分') && !(await text(page, 'tbody')).includes('今月分'), await text(page, 'tbody'))
    check('S2 翌月へ: 内訳も連動（日用品が出る）', (await text(page, '.breakdown-row')).includes('日用品'))
    await page.getByRole('button', { name: '＋ 追加' }).click()
    check('S2 F-05 追加モーダル: 当月以外の日付の初期値はその月の 1 日', (await page.locator('#entry-date').inputValue()) === `${nextMonth}-01`, await page.locator('#entry-date').inputValue())
    await dlg(page).getByRole('button', { name: 'キャンセル' }).click()
    await page.getByRole('button', { name: '◀ 前月' }).click()
    await page.waitForFunction((l) => document.querySelector('.month-nav .current')?.textContent === l, monthLabel)
    await page.waitForFunction(() => document.querySelector('.remaining .value')?.textContent?.includes('75,000'))
    check('S2 前月へ戻る: 元の月の残額 75,000', (await text(page, '.remaining .value')).includes('75,000'))
    await context.close()
  }

  // ---------- S3: 絞り込み中もサマリー不変 / 期間検索の注記 / クリア
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  await mkEntry(today, food, 3000, 'ランチ')
  await mkEntry(today, daily, 500, '洗剤')
  await mkEntry(today, salary, 250000, '9月分')
  await mkEntry(`${now.getFullYear()}-01-10`, food, 900, '正月のランチ')
  {
    const { context, page } = await fresh()
    await open(page)
    const summaryBefore = await text(page, '.summary')
    check('S3 絞り込みなし: 「明細 3件」', (await text(page, '.list-head .count')) === '明細 3件', await text(page, '.list-head .count'))
    check('S3 収入は緑系・支出は赤系', await page.evaluate(() => { const c = (s) => getComputedStyle(document.querySelector(s)).color; return c('.amount.income') !== c('.amount.expense') }))
    await page.locator('#search-category').selectOption({ label: '食費' })
    await page.getByRole('button', { name: '検索' }).click()
    await page.waitForFunction(() => document.querySelector('.list-head .count')?.textContent?.includes('中'))
    check('S3 カテゴリ絞り込み: 「3件中 1件」', (await text(page, '.list-head .count')) === '3件中 1件', await text(page, '.list-head .count'))
    check('S3 絞り込み中もサマリーと内訳が対象月全体のまま', (await text(page, '.summary')) === summaryBefore)
    await page.locator('#search-keyword').fill('存在しない')
    await page.getByRole('button', { name: '検索' }).click()
    await page.waitForFunction(() => document.querySelector('.table-wrap .empty'))
    check('S3 該当 0 件: 「該当するデータがありません」', (await text(page, '.table-wrap .empty')) === '該当するデータがありません')
    await page.getByRole('button', { name: 'クリア' }).click()
    await page.waitForFunction(() => document.querySelector('.list-head .count')?.textContent === '明細 3件')
    check('S3 クリア: 全件表示に戻り、入力もリセット', (await page.locator('#search-keyword').inputValue()) === '' && (await page.locator('tbody tr').count()) === 3)
    // 入力途中では反映されない
    await page.locator('#search-keyword').fill('ランチ')
    check('S3 入力途中の値では一覧・件数が変わらない', (await text(page, '.list-head .count')) === '明細 3件')
    await page.getByRole('button', { name: 'クリア' }).click()
    // 期間検索（対象月の外を含む）
    await page.locator('#search-from').fill(`${now.getFullYear()}-01-01`)
    await page.locator('input[aria-label="終了日"]').fill(today)
    await page.getByRole('button', { name: '検索' }).click()
    await page.waitForFunction(() => document.querySelector('.list-head .count')?.textContent?.includes('該当'))
    check('S3 期間検索: 件数表示が「該当 n件（期間）」形式', (await text(page, '.list-head .count')) === `該当 4件（${now.getFullYear()}/01/01〜${today.replaceAll('-', '/')}）`, await text(page, '.list-head .count'))
    check('S3 期間検索: サマリー領域に「表示中の期間」注記', (await text(page, '.remaining .note')) === `表示中の期間: ${monthLabel}`, await text(page, '.remaining .note'))
    check('S3 期間検索: 月をまたいだ行が出る', (await text(page, 'tbody')).includes('正月のランチ'))
    await page.locator('#search-from').fill(`${month}-01`)
    await page.locator('input[aria-label="終了日"]').fill(`${month}-28`)
    await page.getByRole('button', { name: '検索' }).click()
    await page.waitForFunction(() => document.querySelector('.list-head .count')?.textContent?.includes('中'))
    check('S3 期間が対象月内: 注記なし・「3件中 3件」形式', (await page.locator('.remaining .note').count()) === 0 && (await text(page, '.list-head .count')) === '3件中 3件', await text(page, '.list-head .count'))
    await page.locator('#search-from').fill(`${month}-20`)
    await page.locator('input[aria-label="終了日"]').fill(`${month}-10`)
    await page.getByRole('button', { name: '検索' }).click()
    check('S3 from > to: 検索バー下にエラー、直前の一覧を保持', (await text(page, '.field-error')).includes('開始日は終了日より前の日付を指定してください') && (await page.locator('tbody tr').count()) === 3, await text(page, '.field-error'))
    await page.getByRole('button', { name: 'クリア' }).click()
    check('S3 クリア: エラーが消える', (await page.locator('.field-error').count()) === 0)
    await context.close()
  }

  // ---------- S4: バリデーション（フロント）と 400（サーバ）
  resetDb()
  {
    const { context, page } = await fresh()
    await open(page)
    await page.getByRole('button', { name: '＋ 追加' }).click()
    await page.locator('#entry-date').fill('')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    const errs = await page.locator('dialog[open] .field-error').allInnerTexts()
    check('S4 空で保存: 日付・カテゴリ・金額の下にメッセージ', errs.includes('日付を入力してください') && errs.includes('カテゴリを選択してください') && errs.includes('金額は1以上の整数で入力してください'), JSON.stringify(errs))
    check('S4 エラー欄が赤枠（invalid）', (await page.locator('dialog[open] .invalid').count()) >= 3)
    await page.locator('#entry-amount').fill('12.5')
    check('S4 欄を編集するとその欄のエラーだけ消える', (await page.locator('dialog[open] .field-error').count()) === 2)
    await dlg(page).getByRole('button', { name: '保存' }).click()
    check('S4 小数の金額はエラー', (await text(page, 'dialog[open] .field:has(#entry-amount) .field-error')) === '金額は1以上の整数で入力してください')
    await page.locator('#entry-amount').fill('10000000')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    check('S4 上限超え(10,000,000)はエラー', (await text(page, 'dialog[open] .field:has(#entry-amount) .field-error')) === '金額は1以上の整数で入力してください')
    await page.locator('#entry-memo').fill('あ'.repeat(201))
    await dlg(page).getByRole('button', { name: '保存' }).click()
    check('S4 メモ 201 文字はエラー', (await text(page, 'dialog[open] .field:has(#entry-memo) .field-error')) === 'メモは200文字以内で入力してください')
    // モーダルの共通挙動
    await page.keyboard.press('Escape')
    check('S4 N-21 Esc でモーダルが閉じる', (await dlg(page).count()) === 0)
    await page.getByRole('button', { name: '＋ 追加' }).click()
    check('S4 N-21 開き直しても日付の入力欄にフォーカス', await page.evaluate(() => document.activeElement?.id === 'entry-date'), await page.evaluate(() => document.activeElement?.id))
    check('S4 開き直すと入力欄とエラーが初期状態', (await page.locator('#entry-amount').inputValue()) === '' && (await page.locator('dialog[open] .field-error').count()) === 0 && (await page.locator('#entry-memo').inputValue()) === '')
    await page.mouse.click(5, 5)
    check('S4 背景（オーバーレイ）を押しても閉じない', (await dlg(page).count()) === 1)
    await dlg(page).getByRole('button', { name: '閉じる' }).click()
    check('S4 「×」で閉じる', (await dlg(page).count()) === 0)
    // 予算のバリデーション
    await page.getByRole('button', { name: '予算を設定' }).click()
    await page.locator('#budget-amount').fill('-1')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    check('S4 予算に負数: メッセージが入力欄の下に出る', (await text(page, 'dialog[open] .field-error')) === '予算は0以上の整数で入力してください')
    await page.locator('#budget-amount').fill('0')
    await dlg(page).getByRole('button', { name: '保存' }).click()
    await page.waitForFunction(() => !document.querySelector('dialog[open]'))
    await page.waitForFunction(() => document.querySelector('.summary-head')?.textContent?.includes('0'))
    check('S4 予算 0 円も登録でき、「未設定」ではなく 0 と表示される', !(await text(page, '.summary-head')).includes('未設定'), await text(page, '.summary-head'))
    await context.close()
  }

  // ---------- S5: 予算超過の表示 / 予算 0 円で支出あり / N-24 / N-02
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 10000 })
  await mkEntry(today, food, 1234567 > 9999999 ? 1 : 22500, '大きな買い物')
  {
    const { context, page } = await fresh()
    await open(page)
    await page.waitForFunction(() => document.querySelector('.remaining .label')?.textContent === '超過')
    check('S5 予算超過: ラベルが「超過」、金額がマイナス表記（-12,500円）', (await text(page, '.remaining')).includes('超過') && (await text(page, '.remaining .value')).replace(/\s/g, '') === '-12,500円', await text(page, '.remaining .value'))
    check('S5 予算超過: 残額と進捗バーが警告色（over クラス）', (await page.locator('.remaining.over').count()) === 1 && (await page.locator('.progress.over').count()) === 1)
    check('S5 予算超過: バーは 100% で止まる', (await page.locator('.progress .fill').evaluate((el) => el.style.width)) === '100%')
    await page.screenshot({ path: `${SHOTS}/s5-over.png` })
    check('S5 N-02 1280px で横スクロールなし', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), await page.evaluate(() => `${document.documentElement.scrollWidth} > ${window.innerWidth}`))
    await context.close()
  }
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 0 })
  await mkEntry(today, food, 300, 'ゼロ予算')
  {
    const { context, page } = await fresh()
    await open(page)
    await page.waitForFunction(() => document.querySelector('.progress'))
    check('S5 予算 0 円で支出あり: 進捗バー 100% の警告色', (await page.locator('.progress .fill').evaluate((el) => el.style.width)) === '100%' && (await page.locator('.progress.over').count()) === 1)
    await context.close()
  }

  // ---------- S6: 編集（同じ区分のカテゴリだけ / 別月へ移すと消える）
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  await mkEntry(today, food, 1000, '編集対象')
  {
    const { context, page } = await fresh()
    await open(page)
    await page.locator('tbody tr').first().getByRole('button', { name: '編集' }).click()
    check('S6 編集モーダル: タイトルと既存値', (await text(page, 'dialog[open] h2')) === '収支を編集' && (await page.locator('#entry-amount').inputValue()) === '1000' && (await page.locator('#entry-memo').inputValue()) === '編集対象')
    check('S6 N-21 編集モーダル: 日付の入力欄にフォーカス', await page.evaluate(() => document.activeElement?.id === 'entry-date'), await page.evaluate(() => document.activeElement?.id))
    check('S6 編集モーダル: カテゴリ候補は同じ収支区分（支出）の 1 グループだけ', JSON.stringify(await page.locator('#entry-category optgroup').evaluateAll((els) => els.map((e) => e.label))) === JSON.stringify(['支出']))
    await page.locator('#entry-category').selectOption({ label: '日用品' })
    await page.locator('#entry-amount').fill('1500')
    await page.locator('#entry-date').fill(`${nextMonth}-05`)
    await dlg(page).getByRole('button', { name: '保存' }).click()
    await page.waitForFunction(() => document.querySelector('.table-wrap .empty'))
    check('S6 別の月へ日付変更: 現在の一覧から消え、サマリーが再計算される（残額 80,000）', (await text(page, '.remaining .value')).includes('80,000'), await text(page, '.remaining .value'))
    await page.getByRole('button', { name: '翌月 ▶' }).click()
    await page.waitForFunction(() => document.querySelector('tbody tr'))
    check('S6 移動先の月に現れる（日用品・1,500）', (await text(page, 'tbody tr')).includes('日用品') && (await text(page, 'tbody tr')).includes('-1,500'), await text(page, 'tbody tr'))
    await context.close()
  }

  // ---------- S7: 一括操作
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  await mkEntry(today, food, 100, 'a')
  await mkEntry(today, food, 200, 'b')
  await mkEntry(today, daily, 300, 'c')
  await mkEntry(today, salary, 5000, 'd')
  {
    const { context, page } = await fresh()
    await open(page)
    check('S7 通常モード: チェックボックスも一括操作バーもない', (await page.locator('tbody input[type=checkbox]').count()) === 0 && (await page.locator('.bulk-bar').count()) === 0)
    await page.getByRole('button', { name: '選択', exact: true }).click()
    check('S7 選択モード: 0 件でも一括操作バーが出る（「0件選択中」）', (await text(page, '.bulk-bar .count')) === '0件選択中')
    check('S7 選択モード: 0 件はカテゴリ・日付・適用・削除が無効、「完了」だけ有効', (await page.locator('.bulk-bar select').isDisabled()) && (await page.locator('.bulk-bar input[type=date]').isDisabled()) && (await page.getByRole('button', { name: '適用' }).isDisabled()) && (await page.locator('.bulk-bar .btn-danger').isDisabled()) && !(await page.getByRole('button', { name: '完了' }).isDisabled()))
    check('S7 選択モード: 行の編集・削除ボタンが消える', (await page.locator('tbody .btn-icon').count()) === 0)
    check('S7 選択モード: 件数表示と「＋ 追加」「選択」が一括操作バーに置き換わる', (await page.locator('.list-head').count()) === 0)
    await page.getByLabel('表示中の全行を選択').check()
    check('S7 ヘッダのチェックで全行選択（4件選択中）', (await text(page, '.bulk-bar .count')) === '4件選択中')
    check('S7 支出と収入が混在: カテゴリ変更が無効になり理由が出る', (await page.locator('.bulk-bar select').isDisabled()) && (await text(page, '.bulk-bar .reason')) === '支出と収入が混在しているため、カテゴリは変更できません', await text(page, '.bulk-bar .reason'))
    await page.getByLabel('表示中の全行を選択').uncheck()
    check('S7 ヘッダのチェック解除で 0 件に戻る', (await text(page, '.bulk-bar .count')) === '0件選択中')
    await page.locator('tbody tr', { hasText: 'a' }).first().locator('input[type=checkbox]').check()
    await page.locator('tbody tr', { hasText: 'b' }).first().locator('input[type=checkbox]').check()
    check('S7 支出だけ選ぶとカテゴリ候補は支出のみ', JSON.stringify(await page.locator('.bulk-bar select optgroup').evaluateAll((els) => els.map((e) => e.label))) === JSON.stringify(['支出']))
    check('S7 「適用」は入力するまで無効', await page.getByRole('button', { name: '適用' }).isDisabled())
    await page.locator('.bulk-bar select').selectOption({ label: '通信費' })
    check('S7 カテゴリを選ぶと「適用」が有効', !(await page.getByRole('button', { name: '適用' }).isDisabled()))
    await page.getByRole('button', { name: '適用' }).click()
    check('S7 一括更新の確認: 内容を具体的に示す', (await text(page, 'dialog[open] .modal-body')).startsWith('2件のカテゴリを「通信費」に変更します。') && (await text(page, 'dialog[open] .modal-body')).includes('変更前の値には戻せません。'), await text(page, 'dialog[open] .modal-body'))
    await dlg(page).getByRole('button', { name: 'キャンセル' }).click()
    check('S7 確認でキャンセル: 何も更新されない', (await text(page, 'tbody')).includes('食費') && !(await text(page, 'tbody')).includes('通信費'))
    await page.locator('.bulk-bar input[type=date]').fill(`${month}-01`)
    await page.getByRole('button', { name: '適用' }).click()
    check('S7 カテゴリと日付の両方指定: 本文に両方', (await text(page, 'dialog[open] .modal-body')).startsWith(`2件のカテゴリを「通信費」に、日付を ${month.replace('-', '/')}/01 に変更します。`), await text(page, 'dialog[open] .modal-body'))
    await dlg(page).getByRole('button', { name: '変更する' }).click()
    await page.waitForFunction(() => !document.querySelector('dialog[open]'))
    await page.waitForFunction(() => document.querySelector('.bulk-bar .count')?.textContent === '0件選択中')
    check('S7 適用後: 選択が解除され（0件選択中）、選択モードは維持される', (await page.locator('.bulk-bar').count()) === 1)
    check('S7 適用後: 該当の 2 件が通信費・日付が 01 日に変わる', (await page.locator('tbody tr', { hasText: '通信費' }).count()) === 2 && (await text(page, 'tbody')).includes(`${month.slice(5)}/01`), await text(page, 'tbody'))
    await page.locator('tbody tr').first().locator('input[type=checkbox]').check()
    await page.locator('tbody tr').nth(1).locator('input[type=checkbox]').check()
    await page.locator('.bulk-bar .btn-danger').click()
    check('S7 一括削除の確認: 件数入り「2件のデータを削除します。」', (await text(page, 'dialog[open] .modal-body')).startsWith('2件のデータを削除します。'), await text(page, 'dialog[open] .modal-body'))
    await dlg(page).getByRole('button', { name: '削除する' }).click()
    await page.waitForFunction(() => document.querySelectorAll('tbody tr').length === 2)
    check('S7 一括削除: 2 件が消える', (await page.locator('tbody tr').count()) === 2)
    await page.getByRole('button', { name: '完了' }).click()
    check('S7 「完了」で通常モードに戻る', (await page.locator('.bulk-bar').count()) === 0 && (await page.locator('.list-head').count()) === 1 && (await page.locator('tbody input[type=checkbox]').count()) === 0)
    await context.close()
  }

  // ---------- S8: 通信失敗・二重送信・タイムアウト（N-22・N-26）
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  await mkEntry(today, food, 100, '既存')
  {
    // API 停止（接続できない）
    const { context, page } = await fresh()
    await open(page)
    await context.route('**/api/**', (route) => route.abort('connectionrefused'))
    await page.getByRole('button', { name: '翌月 ▶' }).click()
    await page.waitForSelector('.error-banner')
    check('S8 N-26 API 停止: エラーバナー「サーバーに接続できませんでした…」', (await text(page, '.error-banner')).startsWith('サーバーに接続できませんでした。時間をおいて再度お試しください'), await text(page, '.error-banner'))
    check('S8 取得失敗の領域は「読み込めませんでした」で、直前の月の値を残さない', (await page.getByText('読み込めませんでした').count()) >= 1 && !(await text(page, 'body')).includes('既存'))
    check('S8 ローディングのまま止まらない', (await page.locator('.loading').count()) === 0)
    await page.locator('.error-banner .btn-icon').click()
    check('S8 バナーは「×」で閉じられる', (await page.locator('.error-banner').count()) === 0)
    await context.unroute('**/api/**')
    await page.getByRole('button', { name: '◀ 前月' }).click()
    await page.waitForFunction(() => document.querySelector('tbody tr'))
    check('S8 次の操作が成功すれば復帰して操作を続けられる', (await text(page, 'tbody')).includes('既存'))
    await context.close()
  }
  {
    // 二重送信
    const { context, page } = await fresh()
    await open(page)
    let posts = 0
    await context.route('**/api/entries', async (route) => {
      if (route.request().method() === 'POST') { posts++; await new Promise((r) => setTimeout(r, 1500)) }
      await route.continue()
    })
    await page.getByRole('button', { name: '＋ 追加' }).click()
    await page.locator('#entry-category').selectOption({ label: '食費' })
    await page.locator('#entry-amount').fill('777')
    const save = dlg(page).getByRole('button', { name: '保存' })
    await save.click()
    check('S8 N-22 送信中は「保存」が無効', await save.isDisabled())
    check('S8 送信中は「キャンセル」・「×」も無効', (await dlg(page).getByRole('button', { name: 'キャンセル' }).isDisabled()) && (await dlg(page).getByRole('button', { name: '閉じる' }).isDisabled()))
    await save.click({ force: true, timeout: 500 }).catch(() => {})
    await page.keyboard.press('Escape')
    await page.waitForFunction(() => !document.querySelector('dialog[open]'), null, { timeout: 8000 })
    await page.waitForFunction(() => document.querySelectorAll('tbody tr').length === 2)
    check('S8 N-22 連打しても POST は 1 回だけで、レコードは重複しない', posts === 1 && (await page.locator('tbody tr', { hasText: '777' }).count()) === 1, `posts=${posts}`)
    await context.close()
  }
  {
    // タイムアウト（応答なし）
    const { context, page } = await fresh()
    await open(page)
    await context.route('**/api/entries', async (route) => { if (route.request().method() === 'POST') return; await route.continue() }) // POST は応答を返さない
    await page.getByRole('button', { name: '＋ 追加' }).click()
    await page.locator('#entry-category').selectOption({ label: '食費' })
    await page.locator('#entry-amount').fill('888')
    const save = dlg(page).getByRole('button', { name: '保存' })
    const t0 = Date.now()
    await save.click()
    check('S8 応答待ちの間は送信中（保存が無効）', await save.isDisabled())
    await page.waitForFunction(() => document.querySelector('dialog[open] .field-error'), null, { timeout: 15000 })
    const sec = (Date.now() - t0) / 1000
    check('S8 N-26 応答がなくても約 10 秒で打ち切られ、モーダル内にエラー', sec >= 9 && sec <= 13 && (await text(page, 'dialog[open] .field-error')).startsWith('サーバーからの応答がありません。時間をおいて再度お試しください'), `${sec}s: ${await text(page, 'dialog[open] .field-error')}`)
    check('S8 タイムアウト後は送信中が解除され、入力を残したまま操作を続けられる', !(await save.isDisabled()) && (await page.locator('#entry-amount').inputValue()) === '888')
    await context.unroute('**/api/entries')
    await context.close()
  }
  {
    // 取得のタイムアウト（無限ローディングにしない）
    const { context, page } = await fresh()
    await context.route('**/api/summary**', () => {}) // 応答しない
    await page.goto(UI)
    await page.locator('.loading').first().waitFor()
    check('S8 取得中はローディング表示', (await page.locator('.loading').count()) >= 1)
    await page.waitForSelector('.error-banner', { timeout: 15000 })
    check('S8 取得が無応答でも打ち切られ、ローディングが止まってバナーに切り替わる', (await text(page, '.error-banner')).startsWith('サーバーからの応答がありません') && (await page.getByText('読み込めませんでした').count()) >= 1, await text(page, '.error-banner'))
    await context.close()
  }

  // ---------- S9: サーバ 400 / 404 の表示先
  resetDb()
  await api('PUT', `/api/budgets/${month}`, { amount: 80000 })
  const gone = await mkEntry(today, food, 400, '消える予定')
  {
    const { context, page } = await fresh()
    await open(page)
    // 編集中に別の操作で消えた → 404 はモーダル内に出て、一覧も取り直される
    await page.locator('tbody tr').first().getByRole('button', { name: '編集' }).click()
    await api('DELETE', `/api/entries/${gone.id}`)
    await dlg(page).getByRole('button', { name: '保存' }).click()
    await page.waitForFunction(() => document.querySelector('dialog[open] .field-error'))
    check('S9 編集で 404: モーダル内にメッセージ（閉じない）', (await text(page, 'dialog[open] .field-error')) === '対象のレコードが見つかりません' && (await dlg(page).count()) === 1, await text(page, 'dialog[open] .field-error'))
    await page.waitForFunction(() => document.querySelector('.table-wrap .empty'))
    check('S9 編集で 404: 背後の一覧・サマリーが取り直されている', (await text(page, '.table-wrap .empty')) === 'この月のデータがありません' && (await text(page, '.remaining .value')).includes('80,000'))
    await context.close()
  }
  {
    // 削除で 404 → ダイアログを閉じ、バナー、取り直し
    const target = await mkEntry(today, food, 450, '削除で消える')
    const { context, page } = await fresh()
    await open(page)
    await page.locator('tbody tr').first().getByRole('button', { name: '削除' }).click()
    await api('DELETE', `/api/entries/${target.id}`)
    await dlg(page).getByRole('button', { name: '削除する' }).click()
    await page.waitForSelector('.error-banner')
    check('S9 削除で 404: ダイアログが閉じ、エラーバナーに API のメッセージ', (await dlg(page).count()) === 0 && (await text(page, '.error-banner')).startsWith('対象のレコードが見つかりません'), await text(page, '.error-banner'))
    check('S9 削除で 404: 一覧が取り直される', (await text(page, '.table-wrap .empty')) === 'この月のデータがありません')
    await context.close()
  }
} finally {
  await browser.close()
  resetDb()
}

const failed = results.filter((r) => !r.ok)
console.log(`\n=== ${results.length - failed.length}/${results.length} PASS ===`)
for (const f of failed) console.log(`FAIL: ${f.name}  ${f.detail}`)
process.exit(failed.length ? 1 : 0)
