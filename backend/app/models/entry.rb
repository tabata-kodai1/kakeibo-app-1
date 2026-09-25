class Entry < ApplicationRecord
  AMOUNT_MAX = 9_999_999
  MEMO_MAX_LENGTH = 200

  # category の存在は category_id のエラーとして返す（API のエラーキーを category_id にそろえる）
  belongs_to :category, optional: true

  # 空白のみの入力は未入力として扱い null で保存する
  normalizes :memo, with: ->(memo) { memo.match?(/\A[[:space:]]*\z/) ? nil : memo }

  scope :in_month, ->(month) { where(entry_date: month.range) }
  # 新しい記録が上。同日なら id の降順（docs/features.md「レコードの JSON 表現」）
  scope :newest_first, -> { order(entry_date: :desc, id: :desc) }

  validates :entry_date, presence: { message: "日付を入力してください" }
  validates :category_id, presence: { message: "カテゴリを選択してください" }
  validate :category_must_exist
  validate :category_type_must_not_change, on: :update
  validates :amount, numericality: {
    only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: AMOUNT_MAX,
    message: "金額は1以上の整数で入力してください"
  }
  validates :memo, length: { maximum: MEMO_MAX_LENGTH, message: "メモは200文字以内で入力してください" }
  validates :memo, format: { without: /[\r\n]/, message: "メモに改行は含められません" }, allow_nil: true

  private

  def category_must_exist
    return if category_id.blank? || category.present?

    errors.add(:category_id, "カテゴリを選択してください")
  end

  # 支出と収入をまたぐ付け替えは、残額が大きく動くのに「カテゴリを直しただけ」に見えるため認めない（F-06）。
  # 変更後のカテゴリが存在しないときは、カテゴリ未選択のエラーのほうを返す
  def category_type_must_not_change
    return unless category_id_changed? && category.present?

    before = Category.find_by(id: category_id_was)
    return if before.nil? || before.category_type == category.category_type

    errors.add(:category_id, "支出と収入をまたぐカテゴリ変更はできません")
  end
end
