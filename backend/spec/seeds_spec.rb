require "rails_helper"

RSpec.describe "db/seeds.rb" do
  it "13 件のカテゴリを投入し、再実行しても重複しない" do
    2.times { Rails.application.load_seed }

    expect(Category.count).to eq 13
    expect(Category.where(category_type: Category::EXPENSE).count).to eq 9
    expect(Category.where(category_type: Category::INCOME).count).to eq 4
  end
end
