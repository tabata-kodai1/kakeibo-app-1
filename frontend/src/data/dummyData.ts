// フェーズ4 の間だけ使うダミーデータ。フェーズ5 で API（src/api/）に置き換える。
//
// 明細・予算・カテゴリを 1 か所に持ち、サマリーはそこから計算する。実際の API と同じく、
// サマリーは検索条件の影響を受けず、明細一覧だけが絞り込まれる。
// 月ごとに画面の各状態を確かめられるようにしてある。
//
//   2026-09  正常（12 件。予算 80,000 / 支出 52,300 / 残り 27,700）
//   2026-08  予算超過
//   2026-07  予算未設定
//   2026-06  予算 0 円で支出あり
//   2026-05  予算 0 円で支出なし（データなし）
//   2026-04  予算あり・データなし
//   それ以外  予算未設定・データなし

import type { Category, Entry, SearchConditions, Summary } from '../types'

// docs/database.md「初期データ」のシードと同じ並び・ID
export const dummyCategories: Category[] = [
  { id: 1, name: '食費', category_type: 'EXPENSE' },
  { id: 2, name: '日用品', category_type: 'EXPENSE' },
  { id: 3, name: '交通費', category_type: 'EXPENSE' },
  { id: 4, name: '住居費', category_type: 'EXPENSE' },
  { id: 5, name: '水道光熱費', category_type: 'EXPENSE' },
  { id: 6, name: '通信費', category_type: 'EXPENSE' },
  { id: 7, name: '娯楽費', category_type: 'EXPENSE' },
  { id: 8, name: '医療費', category_type: 'EXPENSE' },
  { id: 9, name: 'その他', category_type: 'EXPENSE' },
  { id: 10, name: '給与', category_type: 'INCOME' },
  { id: 11, name: '賞与', category_type: 'INCOME' },
  { id: 12, name: '副収入', category_type: 'INCOME' },
  { id: 13, name: 'その他収入', category_type: 'INCOME' },
]

const FOOD = 1
const DAILY = 2
const TRANSPORT = 3
const HOUSING = 4
const ENTERTAINMENT = 7
const SALARY = 10
const SIDE_INCOME = 12

let nextId = 1
function entry(
  entry_date: string,
  category_id: number,
  amount: number,
  memo: string | null,
): Entry {
  const category = dummyCategories.find((c) => c.id === category_id)!
  return {
    id: nextId++,
    entry_date,
    category_id,
    category_name: category.name,
    category_type: category.category_type,
    amount,
    memo,
  }
}

const entries: Entry[] = [
  // 2026-09（12 件。食費 32,100 / 日用品 8,200 / 娯楽費 8,000 / 交通費 4,000 = 支出 52,300）
  entry('2026-09-25', FOOD, 1_280, 'スーパーで買い物'),
  entry('2026-09-25', SALARY, 250_000, '9月分'),
  entry('2026-09-24', TRANSPORT, 820, '定期外の電車賃'),
  entry('2026-09-23', DAILY, 2_200, '洗剤とティッシュ'),
  entry('2026-09-20', ENTERTAINMENT, 8_000, '映画と食事'),
  entry('2026-09-18', FOOD, 980, 'コンビニ'),
  entry('2026-09-17', SIDE_INCOME, 3_000, 'フリマの売上'),
  entry('2026-09-15', FOOD, 9_840, 'まとめ買い'),
  entry('2026-09-12', DAILY, 1_800, '電球'),
  entry(
    '2026-09-08',
    FOOD,
    20_000,
    '実家への帰省前にまとめて買い出しをして、そのまま家族と外食したときの分',
  ),
  entry('2026-09-05', DAILY, 4_200, '収納ボックス'),
  entry('2026-09-03', TRANSPORT, 3_180, '出張の交通費'),
  // 2026-08（支出 72,500。予算 60,000 を超過）
  entry('2026-08-27', HOUSING, 45_000, '家賃'),
  entry('2026-08-25', SALARY, 250_000, '8月分'),
  entry('2026-08-20', FOOD, 12_000, '食材'),
  entry('2026-08-15', ENTERTAINMENT, 6_000, 'ライブのチケット'),
  entry('2026-08-12', FOOD, 7_500, '外食'),
  entry('2026-08-04', FOOD, 2_000, 'コンビニ'),
  // 2026-07（予算未設定）
  entry('2026-07-25', SALARY, 250_000, '7月分'),
  entry('2026-07-22', FOOD, 11_000, '食材'),
  entry('2026-07-14', TRANSPORT, 3_200, '電車'),
  entry('2026-07-09', FOOD, 7_000, '外食'),
  // 2026-06（予算 0 円で支出あり）
  entry('2026-06-18', ENTERTAINMENT, 5_000, '映画'),
]

// 予算未設定の月はキーがない（予算 0 円とは別の状態）
const budgets: Record<string, number> = {
  '2026-09': 80_000,
  '2026-08': 60_000,
  '2026-06': 0,
  '2026-05': 0,
  '2026-04': 50_000,
}

function monthOf(date: string): string {
  return date.slice(0, 7)
}

/** 新しい記録が上。同日なら id の降順（docs/features.md「レコードの JSON 表現」） */
function newestFirst(a: Entry, b: Entry): number {
  return a.entry_date === b.entry_date ? b.id - a.id : a.entry_date < b.entry_date ? 1 : -1
}

// API がサーバー側で行う計算（docs/features.md F-01・F-03）を、ダミーの組み立てのために写している。
// フェーズ5 で API に置き換えるときに消える
export function getDummySummary(month: string): Summary {
  const inMonth = entries.filter((e) => monthOf(e.entry_date) === month)
  const expenses = inMonth.filter((e) => e.category_type === 'EXPENSE')
  const expenseTotal = expenses.reduce((sum, e) => sum + e.amount, 0)
  const incomeTotal = inMonth
    .filter((e) => e.category_type === 'INCOME')
    .reduce((sum, e) => sum + e.amount, 0)

  const budget = budgets[month] ?? null
  const remaining = budget === null ? null : budget - expenseTotal

  const byCategory = new Map<number, { name: string; amount: number }>()
  for (const e of expenses) {
    const row = byCategory.get(e.category_id) ?? { name: e.category_name, amount: 0 }
    row.amount += e.amount
    byCategory.set(e.category_id, row)
  }

  return {
    month,
    budget,
    expense_total: expenseTotal,
    income_total: incomeTotal,
    remaining,
    usage_rate: budget ? Math.round((expenseTotal * 100) / budget) : null,
    over_budget: remaining !== null && remaining < 0,
    entry_count: inMonth.length,
    categories: [...byCategory]
      .sort(([idA, a], [idB, b]) => b.amount - a.amount || idA - idB)
      .map(([category_id, row]) => ({
        category_id,
        category_name: row.name,
        amount: row.amount,
        rate: Math.round((row.amount * 100) / expenseTotal),
      })),
  }
}

/**
 * GET /api/entries に相当する絞り込み（docs/features.md F-04・F-08）。
 * from / to のどちらかがあれば month を無視して期間で絞る（境界日を含む）。複数条件は AND。
 * キーワードはメモの部分一致で、大文字小文字を区別しない。
 */
function searchEntries(month: string, conditions: SearchConditions): Entry[] {
  const { category_id, from, to } = conditions
  const keyword = conditions.keyword.trim().toLowerCase()
  const byPeriod = from !== '' || to !== ''

  return entries
    .filter((e) => {
      if (byPeriod) {
        if (from !== '' && e.entry_date < from) return false
        if (to !== '' && e.entry_date > to) return false
      } else if (monthOf(e.entry_date) !== month) {
        return false
      }
      if (category_id !== null && e.category_id !== category_id) return false
      if (keyword !== '' && !(e.memo ?? '').toLowerCase().includes(keyword)) return false
      return true
    })
    .sort(newestFirst)
}

/** 通信中の表示（ローディング）を確かめられるよう、API と同じく非同期にして少し待たせる */
export async function fetchDummyEntries(
  month: string,
  conditions: SearchConditions,
  delayMs = 300,
): Promise<Entry[]> {
  await new Promise((resolve) => setTimeout(resolve, delayMs))
  return searchEntries(month, conditions)
}
