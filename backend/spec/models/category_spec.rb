require "rails_helper"

RSpec.describe Category, type: :model do
  it "有効なファクトリで保存できる" do
    expect(build(:category)).to be_valid
  end

  it "名前がなければ無効" do
    expect(build(:category, name: "")).not_to be_valid
  end

  it "名前が 51 文字以上なら無効" do
    expect(build(:category, name: "あ" * 51)).not_to be_valid
    expect(build(:category, name: "あ" * 50)).to be_valid
  end

  it "category_type が INCOME / EXPENSE 以外なら無効" do
    expect(build(:category, category_type: "OTHER")).not_to be_valid
  end

  it "category_type の小文字表記は無効（DB のチェック制約は ci で通してしまうため）" do
    expect(build(:category, category_type: "income")).not_to be_valid
  end

  it "同じ区分内で名前が重複すれば無効" do
    create(:category, name: "重複確認用", category_type: Category::EXPENSE)
    expect(build(:category, name: "重複確認用", category_type: Category::EXPENSE)).not_to be_valid
  end

  it "区分が違えば同じ名前でも有効" do
    create(:category, name: "重複確認用", category_type: Category::EXPENSE)
    expect(build(:category, name: "重複確認用", category_type: Category::INCOME)).to be_valid
  end

  it "使用中のカテゴリは DB の外部キー制約で削除できない" do
    entry = create(:entry)
    expect { entry.category.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
