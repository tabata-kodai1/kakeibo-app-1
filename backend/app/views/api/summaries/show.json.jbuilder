json.(@summary, :month, :budget, :expense_total, :income_total, :remaining, :usage_rate, :over_budget, :entry_count)
json.categories @summary.categories do |row|
  json.(row, :category_id, :category_name, :amount, :rate)
end
