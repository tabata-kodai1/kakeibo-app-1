// 画面が使う API 呼び出し（docs/features.md「API 一覧」）。取得系。更新系は別の Issue で足す。
import type { Category, Entry, SearchConditions, Summary } from '../types'
import { request } from './client'

export { ApiError } from './client'
export type { ApiErrorKind } from './client'

/** GET /api/categories */
export function fetchCategories(): Promise<Category[]> {
  return request<Category[]>('GET', '/api/categories')
}

/** GET /api/summary?month=YYYY-MM。サマリーと、カテゴリ別の内訳（categories）を返す */
export function fetchSummary(month: string): Promise<Summary> {
  return request<Summary>('GET', '/api/summary', { query: { month } })
}

/**
 * GET /api/entries。from / to のどちらかがあれば API が month を無視して期間で絞る（F-08）。
 * 空の条件は client が送らない。
 */
export function fetchEntries(month: string, conditions: SearchConditions): Promise<Entry[]> {
  return request<Entry[]>('GET', '/api/entries', {
    query: {
      month,
      category_id: conditions.category_id,
      keyword: conditions.keyword.trim(),
      from: conditions.from,
      to: conditions.to,
    },
  })
}
