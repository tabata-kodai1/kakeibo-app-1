# 月次サマリー（F-01）とカテゴリ別集計（F-03）。集計は SQL で求め、アプリ側ではループして足さない（N-03）
class MonthlySummary
  Row = Data.define(:category_id, :category_name, :amount, :rate)

  def initialize(month)
    @month = month
  end

  def month
    @month.to_s
  end

  # 予算未設定は行が存在しない状態で nil。予算 0 円（行はある）とは別の状態
  def budget
    return @budget if defined?(@budget)

    @budget = Budget.find_by(year_month: month)&.amount
  end

  def expense_total
    totals.fetch(Category::EXPENSE, [ 0, 0 ]).first
  end

  def income_total
    totals.fetch(Category::INCOME, [ 0, 0 ]).first
  end

  # 検索条件の影響を受けない、対象月の総件数（収入・支出の両方）
  def entry_count
    totals.values.sum(&:last)
  end

  # 収入は含めない。予算が未設定なら計算できないので nil
  def remaining
    budget && budget - expense_total
  end

  # 予算が 0 または未設定なら nil（0 除算を避ける）
  def usage_rate
    return if budget.nil? || budget.zero?

    (expense_total * 100.0 / budget).round
  end

  def over_budget
    !remaining.nil? && remaining.negative?
  end

  def categories
    @categories ||= expense_by_category.map do |id, name, amount|
      Row.new(category_id: id, category_name: name, amount: amount, rate: (amount * 100.0 / expense_total).round)
    end
  end

  private

  def month_entries
    Entry.in_month(@month).joins(:category)
  end

  # { "EXPENSE" => [合計, 件数], "INCOME" => [...] }。レコードのない区分はキーがない
  def totals
    @totals ||= month_entries
      .group("categories.category_type")
      .pluck("categories.category_type", Arel.sql("SUM(entries.amount)"), Arel.sql("COUNT(*)"))
      .to_h { |category_type, sum, count| [ category_type, [ sum.to_i, count ] ] }
  end

  # 使った順。同額なら category_id 順にして並びを固定する
  def expense_by_category
    month_entries
      .where(categories: { category_type: Category::EXPENSE })
      .group("categories.id", "categories.name")
      .order(Arel.sql("SUM(entries.amount) DESC"), "categories.id")
      .pluck("categories.id", "categories.name", Arel.sql("SUM(entries.amount)"))
      .map { |id, name, sum| [ id, name, sum.to_i ] }
  end
end
