import type { CategoryType } from '../types'

// 桁区切りは Intl.NumberFormat に任せ、自前で書かない（docs/plan.md フェーズ4「先に決めること」）
const amountFormatter = new Intl.NumberFormat('ja-JP')

/** 27700 → "27,700" */
export function formatAmount(amount: number): string {
  return amountFormatter.format(amount)
}

/** 明細の金額。支出は "-1,280"、収入は "+250,000" */
export function formatSignedAmount(amount: number, categoryType: CategoryType): string {
  return `${categoryType === 'INCOME' ? '+' : '-'}${formatAmount(amount)}`
}

/** 明細の日付列。"2026-09-25" → "09/25" */
export function formatShortDate(date: string): string {
  return date.slice(5).replace('-', '/')
}

/** "2026-09" → "2026年9月" */
export function formatMonthLabel(month: string): string {
  const [year, monthNumber] = month.split('-')
  return `${year}年${Number(monthNumber)}月`
}

/** 今日の月（yyyy-MM）。画面の初期表示の対象月 */
export function currentMonth(now: Date = new Date()): string {
  return toMonth(now.getFullYear(), now.getMonth() + 1)
}

/** 収支入力モーダルの日付の初期値。対象月が当月なら本日、それ以外ならその月の 1 日（docs/features.md F-05） */
export function defaultEntryDate(month: string, today: Date = new Date()): string {
  if (currentMonth(today) !== month) return `${month}-01`
  return `${month}-${String(today.getDate()).padStart(2, '0')}`
}

/** 月を前後に動かす。shiftMonth("2026-01", -1) → "2025-12" */
export function shiftMonth(month: string, delta: number): string {
  const [year, monthNumber] = month.split('-').map(Number)
  const index = year * 12 + (monthNumber - 1) + delta
  return toMonth(Math.floor(index / 12), (index % 12) + 1)
}

function toMonth(year: number, monthNumber: number): string {
  return `${year}-${String(monthNumber).padStart(2, '0')}`
}
