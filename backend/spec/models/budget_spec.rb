require "rails_helper"

RSpec.describe Budget, type: :model do
  it "有効なファクトリで保存できる" do
    expect(build(:budget)).to be_valid
  end

  describe "year_month" do
    it "yyyy-MM 形式は有効" do
      expect(build(:budget, year_month: "2026-09")).to be_valid
    end

    it "形式が違えば無効" do
      [ nil, "", "2026-9", "2026/09", "202609", "2026-13", "2026-00", "2026-09-01" ].each do |value|
        budget = build(:budget, year_month: value)
        expect(budget).not_to be_valid, "year_month=#{value.inspect} が有効になっている"
        expect(budget.errors[:year_month]).to include "対象月の形式が不正です"
      end
    end

    it "同じ月の予算が重複すれば無効" do
      create(:budget, year_month: "2026-09")
      expect(build(:budget, year_month: "2026-09")).not_to be_valid
    end

    it "DB の一意制約でも重複を弾く" do
      create(:budget, year_month: "2026-09")
      expect { build(:budget, year_month: "2026-09").save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "amount" do
    it "0 と 99,999,999 は有効（予算 0 円は未設定と別の状態）" do
      expect(build(:budget, amount: 0)).to be_valid
      expect(build(:budget, amount: 99_999_999)).to be_valid
    end

    it "負数・100,000,000 以上・小数・nil は無効" do
      [ -1, 100_000_000, 1.5, nil ].each do |amount|
        budget = build(:budget, amount: amount)
        expect(budget).not_to be_valid, "amount=#{amount.inspect} が有効になっている"
        expect(budget.errors[:amount]).to eq [ "予算は0以上の整数で入力してください" ]
      end
    end

    it "DB のチェック制約でも範囲外を弾く" do
      budget = build(:budget, amount: -1)
      expect { budget.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
