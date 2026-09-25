FactoryBot.define do
  factory :budget do
    sequence(:year_month) { |n| format("2026-%02d", (n - 1) % 12 + 1) }
    amount { 100_000 }
  end
end
