class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, limit: 50, null: false
      # `type` は ActiveRecord が STI 用に予約しているため、列名は category_type にする
      t.string :category_type, limit: 10, null: false
      t.datetime :created_at, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }

      t.index %i[name category_type], unique: true
      # 照合順序が ci のため、小文字の 'income' なども通る。表記ゆれはモデルの inclusion で防ぐ
      t.check_constraint "category_type IN ('INCOME', 'EXPENSE')", name: "categories_category_type_check"
    end
  end
end
