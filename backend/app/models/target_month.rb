# 集計・一覧の対象月（yyyy-MM）。月の絞り込みは範囲比較で書く（docs/database.md「月の絞り込み方法」）
class TargetMonth
  attr_reader :first_day

  # nil（パラメータなし）は当月。当月の判定は config.time_zone（Asia/Tokyo）の日付による。
  # 形式が不正なら nil を返す
  def self.parse(value)
    return new(Time.zone.today.beginning_of_month) if value.nil?
    return unless value.is_a?(String) && value.match?(Budget::YEAR_MONTH_FORMAT)

    new(Date.strptime(value, "%Y-%m"))
  end

  def initialize(first_day)
    @first_day = first_day
  end

  # 翌月 1 日を含まない範囲。where に渡すと `>= 月初 AND < 翌月初` になる
  def range
    first_day...first_day.next_month
  end

  def to_s
    first_day.strftime("%Y-%m")
  end
end
