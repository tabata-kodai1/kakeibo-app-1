class Category < ApplicationRecord
  INCOME = "INCOME".freeze
  EXPENSE = "EXPENSE".freeze
  CATEGORY_TYPES = [ INCOME, EXPENSE ].freeze

  has_many :entries

  validates :name, presence: true, length: { maximum: 50 }
  # DB のチェック制約は照合順序 ci のため小文字を通してしまう。表記ゆれはここで弾く
  validates :category_type, inclusion: { in: CATEGORY_TYPES }
  validates :name, uniqueness: { scope: :category_type }
end
