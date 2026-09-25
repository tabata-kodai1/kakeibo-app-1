class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      t.string :year_month, limit: 7, null: false
      t.integer :amount, null: false
      t.datetime :created_at, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }
      t.datetime :updated_at, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }

      # 1 か月に予算が 2 つできることを DB レベルで防ぐ。F-02 の「上書き」の土台
      t.index :year_month, unique: true
      t.check_constraint "amount >= 0 AND amount <= 99999999", name: "budgets_amount_check"
    end
  end
end
