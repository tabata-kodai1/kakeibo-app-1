// 画面が使う API 呼び出し（docs/features.md「API 一覧」）。
import type { Budget, Category, Entry, EntryPayload, SearchConditions, Summary } from '../types'
import { request } from './client'

export { ApiError, asApiError } from './client'
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

// --- 更新系。成功したあとの画面は、API から取り直す（docs/screens.md「更新に成功したあとの画面」）

/** POST /api/entries（201） */
export function createEntry(payload: EntryPayload): Promise<Entry> {
  return request<Entry>('POST', '/api/entries', { body: payload })
}

/** PUT /api/entries/{id}。4 項目すべてを置き換える（memo を省略すると null になる） */
export function updateEntry(id: number, payload: EntryPayload): Promise<Entry> {
  return request<Entry>('PUT', `/api/entries/${id}`, { body: payload })
}

/** DELETE /api/entries/{id}（204） */
export function deleteEntry(id: number): Promise<void> {
  return request<void>('DELETE', `/api/entries/${id}`)
}

/** PUT /api/budgets/{year_month}。未登録なら作成（201）、登録済みなら上書き（200） */
export function saveBudget(month: string, amount: number): Promise<Budget> {
  return request<Budget>('PUT', `/api/budgets/${month}`, { body: { amount } })
}

/** 一括更新で変える項目。指定した項目だけを更新する（両方指定も可） */
export interface BulkChanges {
  category_id?: number
  entry_date?: string
}

/** PATCH /api/entries/bulk。1 件でも存在しない ID があれば 404 で、1 件も更新されない */
export function bulkUpdateEntries(
  ids: number[],
  changes: BulkChanges,
): Promise<{ updated_count: number }> {
  return request('PATCH', '/api/entries/bulk', { body: { ids, ...changes } })
}

/** DELETE /api/entries/bulk。専用のエンドポイントを 1 回だけ呼ぶ（1 件ずつ繰り返さない） */
export function bulkDeleteEntries(ids: number[]): Promise<{ deleted_count: number }> {
  return request('DELETE', '/api/entries/bulk', { body: { ids } })
}
