// フェーズ4 の間だけ使うダミーデータ。フェーズ5 で API（src/api/）に置き換える。
// 月ごとに画面の各状態を確かめられるようにしてある。
//
//   2026-09  正常（モックアップと同じ数値）
//   2026-08  予算超過
//   2026-07  予算未設定
//   2026-06  予算 0 円で支出あり
//   2026-05  予算 0 円で支出なし
//   2026-04  予算あり・データなし
//   それ以外  予算未設定・データなし

import type { Summary } from '../types'

type ExpenseRow = { id: number; name: string; amount: number }

// API がサーバー側で行う計算（docs/features.md F-01 の計算規則）を、ダミーの組み立てのために写している
function summarize(
  month: string,
  budget: number | null,
  expenses: ExpenseRow[],
  incomeTotal: number,
  entryCount: number,
): Summary {
  const expenseTotal = expenses.reduce((sum, row) => sum + row.amount, 0)
  const remaining = budget === null ? null : budget - expenseTotal

  return {
    month,
    budget,
    expense_total: expenseTotal,
    income_total: incomeTotal,
    remaining,
    usage_rate: budget ? Math.round((expenseTotal * 100) / budget) : null,
    over_budget: remaining !== null && remaining < 0,
    entry_count: entryCount,
    categories: [...expenses]
      .sort((a, b) => b.amount - a.amount)
      .map((row) => ({
        category_id: row.id,
        category_name: row.name,
        amount: row.amount,
        rate: Math.round((row.amount * 100) / expenseTotal),
      })),
  }
}

const food = (amount: number): ExpenseRow => ({ id: 1, name: '食費', amount })
const daily = (amount: number): ExpenseRow => ({ id: 2, name: '日用品', amount })
const transport = (amount: number): ExpenseRow => ({ id: 3, name: '交通費', amount })
const housing = (amount: number): ExpenseRow => ({ id: 4, name: '住居費', amount })
const entertainment = (amount: number): ExpenseRow => ({ id: 7, name: '娯楽費', amount })

const summaries: Record<string, Summary> = {
  '2026-09': summarize(
    '2026-09',
    80_000,
    [food(32_100), daily(8_200), entertainment(8_000), transport(4_000)],
    250_000,
    12,
  ),
  '2026-08': summarize(
    '2026-08',
    60_000,
    [housing(45_000), food(21_500), entertainment(6_000)],
    250_000,
    14,
  ),
  '2026-07': summarize('2026-07', null, [food(18_000), transport(3_200)], 250_000, 9),
  '2026-06': summarize('2026-06', 0, [entertainment(5_000)], 0, 1),
  '2026-05': summarize('2026-05', 0, [], 0, 0),
  '2026-04': summarize('2026-04', 50_000, [], 0, 0),
}

export function getDummySummary(month: string): Summary {
  return summaries[month] ?? summarize(month, null, [], 0, 0)
}
