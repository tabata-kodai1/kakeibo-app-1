import type { SearchConditions } from '../types'
import { formatMonthLabel } from './format'

// 明細一覧の件数表示・空表示・期間注記を決める判定（docs/screens.md S-01「検索条件の扱い」「明細一覧」）。
// 判定は「反映済みの条件」で行う。入力途中の値では変えない。

export function emptyConditions(): SearchConditions {
  return { category_id: null, keyword: '', from: '', to: '' }
}

/** 絞り込み中か。反映済みのカテゴリ・キーワード・from・to のいずれかが指定されている。キーワードは空白のみなら指定なし */
export function isFiltered(conditions: SearchConditions): boolean {
  return (
    conditions.category_id !== null ||
    conditions.keyword.trim() !== '' ||
    conditions.from !== '' ||
    conditions.to !== ''
  )
}

/** from が to より後か（このとき検索は 400 になる） */
export function isPeriodReversed(conditions: SearchConditions): boolean {
  return conditions.from !== '' && conditions.to !== '' && conditions.from > conditions.to
}

/** "2026-09" → "2026-09-30" */
export function lastDayOfMonth(month: string): string {
  const [year, monthNumber] = month.split('-').map(Number)
  const day = new Date(year, monthNumber, 0).getDate()
  return `${month}-${String(day).padStart(2, '0')}`
}

/**
 * 期間検索が対象月の外を含むか。from と to の両方が指定され、両方が対象月の内側にある場合以外は「外を含む」。
 * 片方だけの指定は範囲が月の外へ広がるため、常に「外を含む」。
 * yyyy-MM-dd は文字列のまま大小を比べられる。
 */
export function isPeriodOutsideMonth(conditions: SearchConditions, month: string): boolean {
  const { from, to } = conditions
  if (from === '' && to === '') return false
  if (from === '' || to === '') return true
  return from < `${month}-01` || to > lastDayOfMonth(month)
}

/** "2026-01-01" → "2026/01/01" */
export function toSlashDate(date: string): string {
  return date.replaceAll('-', '/')
}

/** 「2026/01/01〜2026/09/30」。片方だけなら指定のない側を空ける（「2026/01/01〜」「〜2026/09/30」） */
export function formatPeriod(conditions: SearchConditions): string {
  const from = conditions.from === '' ? '' : toSlashDate(conditions.from)
  const to = conditions.to === '' ? '' : toSlashDate(conditions.to)
  return `${from}〜${to}`
}

/**
 * 明細一覧の件数表示。
 *   絞り込みなし                 「明細 12件」
 *   絞り込み中                   「12件中 3件」（母数はサマリーの entry_count）
 *   対象月の外を含む期間検索中   「該当 3件（2026/01/01〜2026/09/30）」（母数は出さない）
 */
export function countLabel(
  conditions: SearchConditions,
  month: string,
  total: number,
  shown: number,
): string {
  if (isPeriodOutsideMonth(conditions, month)) {
    return `該当 ${shown}件（${formatPeriod(conditions)}）`
  }
  if (isFiltered(conditions)) return `${total}件中 ${shown}件`
  return `明細 ${total}件`
}

/** 0 件のときの空表示 */
export function emptyMessage(conditions: SearchConditions): string {
  return isFiltered(conditions) ? '該当するデータがありません' : 'この月のデータがありません'
}

/** サマリー領域の期間注記。明細が対象月の外を含むときだけ、サマリーが指す期間を示す */
export function periodNote(conditions: SearchConditions, month: string): string | null {
  return isPeriodOutsideMonth(conditions, month) ? `表示中の期間: ${formatMonthLabel(month)}` : null
}

/**
 * 一括更新の確認ダイアログの本文（docs/screens.md「一括更新の確認」）。
 * 指定した項目だけを示す。指定していない日付やカテゴリには触れない
 */
export function bulkUpdateMessage(
  count: number,
  categoryName: string | null,
  date: string,
): string {
  const category = categoryName === null ? null : `カテゴリを「${categoryName}」`
  const day = date === '' ? null : `日付を ${toSlashDate(date)} `
  if (category && day) return `${count}件の${category}に、${day}に変更します。`
  if (category) return `${count}件の${category}に変更します。`
  return `${count}件の${day}に変更します。`
}
