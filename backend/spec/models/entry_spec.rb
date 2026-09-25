require "rails_helper"

RSpec.describe Entry, type: :model do
  it "有効なファクトリで保存できる" do
    expect(build(:entry)).to be_valid
  end

  describe "entry_date" do
    it "なければ無効" do
      entry = build(:entry, entry_date: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:entry_date]).to eq [ "日付を入力してください" ]
    end

    it "実在しない日付は無効" do
      expect(build(:entry, entry_date: "2026-02-30")).not_to be_valid
    end

    it "未来日付でも有効" do
      expect(build(:entry, entry_date: Date.current.next_year)).to be_valid
    end
  end

  describe "category_id" do
    it "なければ無効" do
      entry = build(:entry, category: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:category_id]).to eq [ "カテゴリを選択してください" ]
    end

    it "存在しない ID なら無効" do
      entry = build(:entry, category: nil, category_id: 0)
      expect(entry).not_to be_valid
      expect(entry.errors[:category_id]).to eq [ "カテゴリを選択してください" ]
    end
  end

  describe "amount" do
    it "1 と 9,999,999 は有効" do
      expect(build(:entry, amount: 1)).to be_valid
      expect(build(:entry, amount: 9_999_999)).to be_valid
    end

    it "0・負数・10,000,000 以上・小数・文字列・nil は無効" do
      [ 0, -1, 10_000_000, 1.5, "abc", nil ].each do |amount|
        entry = build(:entry, amount: amount)
        expect(entry).not_to be_valid, "amount=#{amount.inspect} が有効になっている"
        expect(entry.errors[:amount]).to eq [ "金額は1以上の整数で入力してください" ]
      end
    end

    it "DB のチェック制約でも範囲外を弾く" do
      entry = build(:entry, amount: 0)
      expect { entry.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "memo" do
    it "未入力（nil）でも有効" do
      expect(build(:entry, memo: nil)).to be_valid
    end

    it "200 文字は有効、201 文字は無効" do
      expect(build(:entry, memo: "あ" * 200)).to be_valid
      entry = build(:entry, memo: "あ" * 201)
      expect(entry).not_to be_valid
      expect(entry.errors[:memo]).to eq [ "メモは200文字以内で入力してください" ]
    end

    it "改行を含むと無効" do
      expect(build(:entry, memo: "1行目\n2行目")).not_to be_valid
    end

    it "空白のみは未入力として nil で保存する" do
      entry = create(:entry, memo: "   　")
      expect(entry.reload.memo).to be_nil
    end
  end
end
