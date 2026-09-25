// 入力の検証（docs/features.md「バリデーション規則」）。メッセージは API と同じものを使う。
// フロントの検証は UX 向けで、正しさの担保はバックエンド（N-13）。
// 誤りがなければ空のオブジェクトを返す。キーは入力欄の名前。

const AMOUNT_MAX = 9_999_999
const BUDGET_MAX = 99_999_999
const MEMO_MAX_LENGTH = 200
const DATE_FORMAT = /^\d{4}-\d{2}-\d{2}$/

export interface EntryFormValues {
  entry_date: string
  category_id: number | null
  /** 入力欄の値のまま（数値として正しいかは検証で見る） */
  amount: string
  memo: string
}

export type EntryFormErrors = Partial<Record<keyof EntryFormValues, string>>

/** yyyy-MM-dd 形式の実在する日付か */
function isRealDate(value: string): boolean {
  if (!DATE_FORMAT.test(value)) return false
  const [year, month, day] = value.split('-').map(Number)
  const date = new Date(year, month - 1, day)
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
}

/** 整数のみ。小数・カンマ付き・指数表記・空は不正 */
function parseInteger(value: string): number | null {
  return /^\d+$/.test(value.trim()) ? Number(value.trim()) : null
}

export function validateEntryForm(values: EntryFormValues): EntryFormErrors {
  const errors: EntryFormErrors = {}

  if (!isRealDate(values.entry_date)) errors.entry_date = '日付を入力してください'
  if (values.category_id === null) errors.category_id = 'カテゴリを選択してください'

  const amount = parseInteger(values.amount)
  if (amount === null || amount < 1 || amount > AMOUNT_MAX) {
    errors.amount = '金額は1以上の整数で入力してください'
  }

  // 文字数は、サロゲートペア（絵文字など）を 1 文字と数える。バックエンド（Ruby）の length と同じ
  if ([...values.memo].length > MEMO_MAX_LENGTH) {
    errors.memo = 'メモは200文字以内で入力してください'
  }

  return errors
}

/** 送信する値。空白のみのメモは未入力として null にする（docs/features.md）。validateEntryForm が通ったあとに呼ぶ */
export function toEntryPayload(values: EntryFormValues) {
  return {
    entry_date: values.entry_date,
    category_id: values.category_id!,
    amount: Number(values.amount.trim()),
    memo: values.memo.trim() === '' ? null : values.memo,
  }
}

/** 予算は 0 以上 99,999,999 以下の整数。誤りがあればメッセージ、なければ null */
export function validateBudget(value: string): string | null {
  const amount = parseInteger(value)
  return amount === null || amount > BUDGET_MAX ? '予算は0以上の整数で入力してください' : null
}
