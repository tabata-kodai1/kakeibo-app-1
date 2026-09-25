FactoryBot.define do
  factory :entry do
    entry_date { Date.new(2026, 9, 15) }
    # build でも category_id が埋まるよう、関連は常に保存する
    association :category, strategy: :create
    amount { 1000 }
    memo { nil }
  end
end
