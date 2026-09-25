# 明細一覧の検索条件（F-04・F-08）。条件の検証と、Entry の絞り込みをここに集める
class EntrySearch
  include ActiveModel::Validations

  # 該当がこれを超える検索は 400 にする（N-28）
  LIMIT = 1_000
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  validate :validate_month, :validate_category_id, :validate_period

  # 未指定・空文字は「条件なし」として扱う。ただし month の空文字は形式不正（省略と区別する）
  def initialize(month: nil, category_id: nil, keyword: nil, from: nil, to: nil)
    @month_param = month
    @category_id_param = category_id.presence
    @keyword = keyword.presence
    @from_param = from.presence
    @to_param = to.presence
  end

  # from / to のどちらかがあれば、month を無視して期間で絞り込む
  def period?
    @from_param.present? || @to_param.present?
  end

  # valid? のあとに呼ぶ。新しい記録が上の並びで返す
  def entries
    scope = Entry.includes(:category)
    scope = period? ? scope.where(entry_date: Range.new(from, to)) : scope.in_month(month)
    scope = scope.where(category_id: @category_id_param.to_i) if @category_id_param
    scope = scope.where("entries.memo LIKE ?", "%#{Entry.sanitize_sql_like(@keyword)}%") if @keyword
    scope.newest_first
  end

  private

  def month
    @month ||= TargetMonth.parse(@month_param)
  end

  def from
    @from ||= parse_date(@from_param)
  end

  def to
    @to ||= parse_date(@to_param)
  end

  def validate_month
    return if period?

    errors.add(:month, "対象月の形式が不正です") if month.nil?
  end

  def validate_category_id
    return if @category_id_param.nil? || (@category_id_param.is_a?(String) && @category_id_param.match?(/\A\d+\z/))

    errors.add(:category_id, "カテゴリの指定が不正です")
  end

  def validate_period
    return unless period?

    errors.add(:from, "開始日の形式が不正です") if @from_param && from.nil?
    errors.add(:to, "終了日の形式が不正です") if @to_param && to.nil?
    return if errors.any?

    errors.add(:from, "開始日は終了日より前の日付を指定してください") if from && to && from > to
  end

  # yyyy-MM-dd 形式の実在する日付だけを受け付ける。不正なら nil
  def parse_date(value)
    return unless value.is_a?(String) && value.match?(DATE_FORMAT)

    Date.strptime(value, "%Y-%m-%d")
  rescue Date::Error
    nil
  end
end
