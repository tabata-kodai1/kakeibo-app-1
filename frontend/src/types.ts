// API の JSON 表現と一致させる（docs/features.md「レコードの JSON 表現」「F-01 月次サマリー」「F-02 予算の設定」）。
// キーは snake_case のまま持ち、変換処理は挟まない（docs/tech-stack.md の命名の方針）。

export type CategoryType = 'INCOME' | 'EXPENSE'

export interface Category {
  id: number
  name: string
  category_type: CategoryType
}

export interface Entry {
  id: number
  /** yyyy-MM-dd */
  entry_date: string
  category_id: number
  category_name: string
  category_type: CategoryType
  amount: number
  memo: string | null
}

/** サマリーの categories の 1 行（F-03）。支出カテゴリのみ */
export interface CategorySummary {
  category_id: number
  category_name: string
  amount: number
  /** 支出合計に占める割合（%）。整数 */
  rate: number
}

export interface Summary {
  /** yyyy-MM */
  month: string
  /** 予算未設定は null。予算 0 円（設定済み）とは別の状態 */
  budget: number | null
  expense_total: number
  income_total: number
  /** budget - expense_total（収入は含めない）。予算未設定は null */
  remaining: number | null
  /** 予算が 0 または未設定なら null */
  usage_rate: number | null
  over_budget: boolean
  /** 対象月の総件数（収入・支出の両方）。検索条件の影響を受けない */
  entry_count: number
  categories: CategorySummary[]
}

export interface Budget {
  /** yyyy-MM */
  year_month: string
  amount: number
}

/**
 * 検索バーの条件（F-08）。API のクエリパラメータに対応する（month は別に持つ）。
 * 未指定は空文字（category_id だけ null）。API も空文字を「指定なし」として扱う。
 */
export interface SearchConditions {
  category_id: number | null
  keyword: string
  /** yyyy-MM-dd */
  from: string
  /** yyyy-MM-dd */
  to: string
}

/** 収支の追加・編集で送る内容（POST /api/entries・PUT /api/entries/{id}）。PUT は 4 項目すべてを置き換える */
export interface EntryPayload {
  entry_date: string
  category_id: number
  amount: number
  /** 空白のみの入力は未入力として null にする */
  memo: string | null
}
