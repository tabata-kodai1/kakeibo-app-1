class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.date :entry_date, null: false
      # 使用中カテゴリの削除を防ぐ
      t.references :category, null: false, foreign_key: { on_delete: :restrict }
      t.integer :amount, null: false
      t.string :memo, limit: 200
      t.datetime :created_at, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }
      t.datetime :updated_at, precision: 6, null: false, default: -> { "CURRENT_TIMESTAMP(6)" }

      # 月別の絞り込みと期間検索用
      t.index :entry_date
      t.check_constraint "amount > 0 AND amount <= 9999999", name: "entries_amount_check"
    end
  end
end
