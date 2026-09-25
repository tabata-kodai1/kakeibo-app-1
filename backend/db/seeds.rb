# カテゴリの初期データ（docs/database.md の「初期データ」）。
# (name, category_type) の一意制約に合わせて find_or_create_by! で流すため、再実行しても重複しない。
# id は採番順の目安で、アプリ側では値を前提にしない。
initial_categories = {
  Category::EXPENSE => %w[食費 日用品 交通費 住居費 水道光熱費 通信費 娯楽費 医療費 その他],
  Category::INCOME => %w[給与 賞与 副収入 その他収入]
}

initial_categories.each do |category_type, names|
  names.each { |name| Category.find_or_create_by!(name: name, category_type: category_type) }
end
