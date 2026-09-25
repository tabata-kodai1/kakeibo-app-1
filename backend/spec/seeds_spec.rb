require "rails_helper"

RSpec.describe "db/seeds.rb" do
  it "13 件のカテゴリを投入し、再実行しても重複しない" do
    # CI の db:prepare が seed 済みの状態でも、空の状態から数えられるようにする
    Category.delete_all
    2.times { Rails.application.load_seed }

    expect(Category.count).to eq 13
    expect(Category.where(category_type: Category::EXPENSE).count).to eq 9
    expect(Category.where(category_type: Category::INCOME).count).to eq 4
  end
end
