require "rails_helper"

# F-01 月次サマリー / F-03 カテゴリ別集計
RSpec.describe "GET /api/summary", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:daily) { create(:category, name: "日用品") }
  let(:salary) { create(:category, :income, name: "給与") }

  def get_summary(month = "2026-09")
    get "/api/summary", params: { month: month }
    response.parsed_body
  end

  it "F-01 の出力形式で返る" do
    create(:budget, year_month: "2026-09", amount: 80_000)
    create(:entry, entry_date: "2026-09-10", category: food, amount: 32_100)
    create(:entry, entry_date: "2026-09-11", category: daily, amount: 8_200)
    create(:entry, entry_date: "2026-09-25", category: salary, amount: 250_000)

    expect(get_summary).to eq(
      "month" => "2026-09",
      "budget" => 80_000,
      "expense_total" => 40_300,
      "income_total" => 250_000,
      "remaining" => 39_700,
      "usage_rate" => 50,
      "over_budget" => false,
      "entry_count" => 3,
      "categories" => [
        { "category_id" => food.id, "category_name" => "食費", "amount" => 32_100, "rate" => 80 },
        { "category_id" => daily.id, "category_name" => "日用品", "amount" => 8_200, "rate" => 20 }
      ]
    )
    expect(response).to have_http_status(:ok)
  end

  describe "集計の対象" do
    it "対象月のレコードだけが集計に含まれる（前月・翌月のデータが混ざらない）" do
      create(:entry, entry_date: "2026-09-01", category: food, amount: 100)
      create(:entry, entry_date: "2026-09-30", category: food, amount: 200)
      create(:entry, entry_date: "2026-08-31", category: food, amount: 1_000)
      create(:entry, entry_date: "2026-10-01", category: food, amount: 10_000)
      create(:entry, entry_date: "2026-08-31", category: salary, amount: 100_000)
      create(:entry, entry_date: "2026-10-01", category: salary, amount: 1_000_000)

      body = get_summary

      expect(body).to include("expense_total" => 300, "income_total" => 0, "entry_count" => 2)
      expect(body["categories"]).to eq([
        { "category_id" => food.id, "category_name" => "食費", "amount" => 300, "rate" => 100 }
      ])
    end

    it "entry_count は収入・支出の両方を数える" do
      create(:entry, entry_date: "2026-09-10", category: food)
      create(:entry, entry_date: "2026-09-10", category: food)
      create(:entry, entry_date: "2026-09-10", category: salary)

      expect(get_summary["entry_count"]).to eq 3
    end

    it "予算は対象月のものだけが使われる（月ごとに独立している）" do
      create(:budget, year_month: "2026-08", amount: 10_000)
      create(:budget, year_month: "2026-09", amount: 80_000)
      create(:budget, year_month: "2026-10", amount: 90_000)

      expect(get_summary["budget"]).to eq 80_000
    end
  end

  describe "予算が未設定の月" do
    it "budget と usage_rate が null で返り、エラーにならない" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 5_000)

      body = get_summary

      expect(response).to have_http_status(:ok)
      expect(body).to have_key("budget")
      expect(body["budget"]).to be_nil
      expect(body).to have_key("usage_rate")
      expect(body["usage_rate"]).to be_nil
    end

    it "expense_total と income_total は計算される" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 5_000)
      create(:entry, entry_date: "2026-09-10", category: salary, amount: 200_000)

      expect(get_summary).to include("expense_total" => 5_000, "income_total" => 200_000)
    end

    it "over_budget は false になる" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 5_000)

      expect(get_summary["over_budget"]).to be false
    end
  end

  describe "残額と超過" do
    it "remaining は budget - expense_total で、収入は含めない" do
      create(:budget, year_month: "2026-09", amount: 80_000)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 52_300)
      create(:entry, entry_date: "2026-09-25", category: salary, amount: 250_000)

      expect(get_summary).to include("remaining" => 27_700, "over_budget" => false)
    end

    it "支出が予算を超えると remaining が負になり over_budget が true になる" do
      create(:budget, year_month: "2026-09", amount: 10_000)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 12_000)

      expect(get_summary).to include("remaining" => -2_000, "over_budget" => true, "usage_rate" => 120)
    end

    it "支出がちょうど予算と同額なら超過ではない" do
      create(:budget, year_month: "2026-09", amount: 10_000)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 10_000)

      expect(get_summary).to include("remaining" => 0, "over_budget" => false, "usage_rate" => 100)
    end

    it "予算 0 円で支出がなければ、usage_rate は null で over_budget は false" do
      create(:budget, year_month: "2026-09", amount: 0)

      body = get_summary

      expect(body["budget"]).to eq 0
      expect(body["usage_rate"]).to be_nil
      expect(body).to include("remaining" => 0, "over_budget" => false)
    end

    it "予算 0 円の月に支出があるとき、over_budget が true になる" do
      create(:budget, year_month: "2026-09", amount: 0)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 500)

      body = get_summary

      expect(body).to include("budget" => 0, "remaining" => -500, "over_budget" => true)
      expect(body["usage_rate"]).to be_nil
    end
  end

  describe "usage_rate の丸め" do
    it "整数に丸める（四捨五入）" do
      create(:budget, year_month: "2026-09", amount: 3)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 2) # 66.67%

      expect(get_summary["usage_rate"]).to eq 67
    end
  end

  describe "レコードが 0 件の月" do
    it "合計 0 でエラーなく返る" do
      body = get_summary

      expect(response).to have_http_status(:ok)
      expect(body).to eq(
        "month" => "2026-09", "budget" => nil, "expense_total" => 0, "income_total" => 0,
        "remaining" => nil, "usage_rate" => nil, "over_budget" => false, "entry_count" => 0,
        "categories" => []
      )
    end

    it "予算が設定済みなら remaining は予算と同額になる" do
      create(:budget, year_month: "2026-09", amount: 80_000)

      expect(get_summary).to include("remaining" => 80_000, "usage_rate" => 0, "over_budget" => false)
    end
  end

  describe "categories（F-03）" do
    it "支出カテゴリのみで、収入カテゴリは含まれない" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 1_000)
      create(:entry, entry_date: "2026-09-10", category: salary, amount: 200_000)

      expect(get_summary["categories"].pluck("category_name")).to eq [ "食費" ]
    end

    it "対象月に使われていないカテゴリは含まれない（0 円の行を出さない）" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 1_000)
      create(:entry, entry_date: "2026-08-10", category: daily, amount: 2_000)
      create(:category, name: "交通費")

      expect(get_summary["categories"].pluck("category_name")).to eq [ "食費" ]
    end

    it "同じカテゴリの複数レコードは合計される" do
      create(:entry, entry_date: "2026-09-10", category: food, amount: 1_000)
      create(:entry, entry_date: "2026-09-20", category: food, amount: 2_500)

      expect(get_summary["categories"].first).to include("amount" => 3_500)
    end

    it "金額の降順（使った順）で並ぶ" do
      transport = create(:category, name: "交通費")
      create(:entry, entry_date: "2026-09-10", category: transport, amount: 4_000)
      create(:entry, entry_date: "2026-09-10", category: food, amount: 32_100)
      create(:entry, entry_date: "2026-09-10", category: daily, amount: 8_200)

      expect(get_summary["categories"].pluck("amount")).to eq [ 32_100, 8_200, 4_000 ]
    end

    it "金額が同じなら category_id の昇順で並ぶ" do
      first = create(:category, name: "先に作ったカテゴリ")
      second = create(:category, name: "後から作ったカテゴリ")
      create(:entry, entry_date: "2026-09-10", category: second, amount: 1_000)
      create(:entry, entry_date: "2026-09-10", category: first, amount: 1_000)

      expect(get_summary["categories"].pluck("category_id")).to eq [ first.id, second.id ]
    end

    it "rate は amount / expense_total * 100 の整数丸めで、合計は概ね 100 になる" do
      transport = create(:category, name: "交通費")
      create(:entry, entry_date: "2026-09-10", category: food, amount: 32_100)
      create(:entry, entry_date: "2026-09-10", category: daily, amount: 8_200)
      create(:entry, entry_date: "2026-09-10", category: transport, amount: 4_000)

      rates = get_summary["categories"].pluck("rate")

      expect(rates).to eq [ 72, 19, 9 ] # 72.46 / 18.51 / 9.03
      expect(rates.sum).to be_between(98, 102)
    end

    it "支出が 0 件の月は空配列になる（収入だけの月でも）" do
      create(:entry, entry_date: "2026-09-10", category: salary, amount: 200_000)

      expect(get_summary["categories"]).to eq []
    end
  end

  describe "month" do
    # 当月の判定はサーバーの Asia/Tokyo の日付による。UTC では 8/31 15:30 だが JST では 9/1 0:30
    it "省略すると当月（Asia/Tokyo）が対象になる" do
      create(:entry, entry_date: "2026-09-15", category: food, amount: 700)
      create(:entry, entry_date: "2026-08-31", category: food, amount: 9_000)

      travel_to Time.utc(2026, 8, 31, 15, 30) do
        get "/api/summary"
      end

      expect(response.parsed_body).to include("month" => "2026-09", "expense_total" => 700)
    end

    [ "2026-13", "2026-9", "abc", "" ].each do |month|
      it "#{month.inspect} は 400 になる" do
        get "/api/summary", params: { month: month }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "対象月の形式が不正です",
          "errors" => { "month" => "対象月の形式が不正です" }
        )
      end
    end
  end
end
