class Budget < ApplicationRecord
  AMOUNT_MAX = 99_999_999
  YEAR_MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  validates :year_month, format: { with: YEAR_MONTH_FORMAT, message: "対象月の形式が不正です" }
  validates :year_month, uniqueness: true
  validates :amount, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: AMOUNT_MAX,
    message: "予算は0以上の整数で入力してください"
  }
end
