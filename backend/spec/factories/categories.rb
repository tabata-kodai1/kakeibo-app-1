FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "カテゴリ#{n}" }
    category_type { Category::EXPENSE }

    trait :income do
      category_type { Category::INCOME }
    end
  end
end
