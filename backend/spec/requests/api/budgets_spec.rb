require "rails_helper"

# F-02 予算の設定
RSpec.describe "PUT /api/budgets/:year_month", type: :request do
  def put_budget(year_month, params)
    put "/api/budgets/#{year_month}", params: params, as: :json
  end

  describe "登録" do
    it "未登録の月なら 201 Created で登録される" do
      expect { put_budget("2026-09", { amount: 80_000 }) }.to change(Budget, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("year_month" => "2026-09", "amount" => 80_000)
      expect(Budget.find_by!(year_month: "2026-09").amount).to eq 80_000
    end

    it "予算 0 円も登録できる" do
      put_budget("2026-09", { amount: 0 })

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("year_month" => "2026-09", "amount" => 0)
    end

    it "上限（99,999,999）ちょうどは登録できる" do
      put_budget("2026-09", { amount: 99_999_999 })

      expect(response).to have_http_status(:created)
    end
  end

  describe "上書き" do
    it "登録済みの月なら 200 OK で上書きされ、レコードは増えない" do
      create(:budget, year_month: "2026-09", amount: 80_000)

      expect { put_budget("2026-09", { amount: 100_000 }) }.not_to change(Budget, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("year_month" => "2026-09", "amount" => 100_000)
      expect(Budget.find_by!(year_month: "2026-09").amount).to eq 100_000
    end

    it "同じ月に 2 回登録すると、2 回目は上書きになる" do
      put_budget("2026-09", { amount: 80_000 })
      expect(response).to have_http_status(:created)

      expect { put_budget("2026-09", { amount: 90_000 }) }.not_to change(Budget, :count)

      expect(response).to have_http_status(:ok)
      expect(Budget.where(year_month: "2026-09").pluck(:amount)).to eq [ 90_000 ]
    end

    it "0 円に上書きできる" do
      create(:budget, year_month: "2026-09", amount: 80_000)

      put_budget("2026-09", { amount: 0 })

      expect(response).to have_http_status(:ok)
      expect(Budget.find_by!(year_month: "2026-09").amount).to eq 0
    end
  end

  it "月ごとに独立していて、他の月の予算に影響しない" do
    create(:budget, year_month: "2026-08", amount: 10_000)
    create(:budget, year_month: "2026-10", amount: 30_000)

    put_budget("2026-09", { amount: 20_000 })

    expect(Budget.order(:year_month).pluck(:year_month, :amount)).to eq [
      [ "2026-08", 10_000 ], [ "2026-09", 20_000 ], [ "2026-10", 30_000 ]
    ]
  end

  describe "金額が不正なとき" do
    invalid_amounts = {
      "負数" => -1,
      "小数" => 1.5,
      "文字列" => "abc",
      "カンマ付き文字列" => "1,000",
      "上限（99,999,999）超え" => 100_000_000,
      "null" => nil
    }

    invalid_amounts.each do |label, amount|
      it "#{label}は 400 になり、何も登録されない" do
        expect { put_budget("2026-09", { amount: amount }) }.not_to change(Budget, :count)

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "予算は0以上の整数で入力してください",
          "errors" => { "amount" => "予算は0以上の整数で入力してください" }
        )
      end
    end

    it "amount キーがなければ 400 になる" do
      put_budget("2026-09", {})

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq("amount" => "予算は0以上の整数で入力してください")
    end

    it "登録済みの月への不正な上書きは 400 になり、元の値が残る" do
      create(:budget, year_month: "2026-09", amount: 80_000)

      put_budget("2026-09", { amount: -1 })

      expect(response).to have_http_status(:bad_request)
      expect(Budget.find_by!(year_month: "2026-09").amount).to eq 80_000
    end
  end

  describe "year_month が不正なとき" do
    [ "2026-13", "2026-00", "2026-9", "202609", "abc" ].each do |year_month|
      it "#{year_month.inspect} は 400 になり、何も登録されない" do
        expect { put_budget(year_month, { amount: 80_000 }) }.not_to change(Budget, :count)

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "対象月の形式が不正です",
          "errors" => { "year_month" => "対象月の形式が不正です" }
        )
      end
    end
  end

  it "予算を削除する API は持たない" do
    create(:budget, year_month: "2026-09", amount: 80_000)

    delete "/api/budgets/2026-09"

    expect(response).to have_http_status(:not_found)
    expect(Budget.count).to eq 1
  end

  it "登録した予算がサマリーに反映される" do
    put_budget("2026-09", { amount: 80_000 })

    get "/api/summary", params: { month: "2026-09" }

    expect(response.parsed_body).to include("budget" => 80_000, "remaining" => 80_000)
  end
end
