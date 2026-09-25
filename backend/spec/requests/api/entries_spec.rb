require "rails_helper"

# F-04 月別明細一覧
RSpec.describe "GET /api/entries", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:salary) { create(:category, :income, name: "給与") }

  it "対象月のレコードだけが返る（前月・翌月のデータが混ざらない）" do
    in_month = create(:entry, entry_date: "2026-09-15", category: food)
    create(:entry, entry_date: "2026-08-31", category: food)
    create(:entry, entry_date: "2026-10-01", category: food)

    get "/api/entries", params: { month: "2026-09" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.pluck("id")).to eq([ in_month.id ])
  end

  it "月初日と月末日のレコードを含む" do
    first_day = create(:entry, entry_date: "2026-09-01", category: food)
    last_day = create(:entry, entry_date: "2026-09-30", category: food)

    get "/api/entries", params: { month: "2026-09" }

    expect(response.parsed_body.pluck("id")).to contain_exactly(first_day.id, last_day.id)
  end

  it "各要素にカテゴリ名と収支区分を含む" do
    entry = create(:entry, entry_date: "2026-09-25", category: food, amount: 1280, memo: "スーパーで買い物")

    get "/api/entries", params: { month: "2026-09" }

    expect(response.parsed_body).to eq([
      {
        "id" => entry.id,
        "entry_date" => "2026-09-25",
        "category_id" => food.id,
        "category_name" => "食費",
        "category_type" => "EXPENSE",
        "amount" => 1280,
        "memo" => "スーパーで買い物"
      }
    ])
  end

  it "収入のレコードは category_type が INCOME で返る" do
    create(:entry, entry_date: "2026-09-25", category: salary, amount: 250_000)

    get "/api/entries", params: { month: "2026-09" }

    expect(response.parsed_body.first).to include("category_name" => "給与", "category_type" => "INCOME")
  end

  it "メモが未入力のレコードは memo が null で返る" do
    create(:entry, entry_date: "2026-09-25", category: food, memo: nil)

    get "/api/entries", params: { month: "2026-09" }

    expect(response.parsed_body.first).to have_key("memo")
    expect(response.parsed_body.first["memo"]).to be_nil
  end

  it "entry_date の降順、同日なら id の降順で返る" do
    old = create(:entry, entry_date: "2026-09-01", category: food)
    same_day_first = create(:entry, entry_date: "2026-09-10", category: food)
    same_day_second = create(:entry, entry_date: "2026-09-10", category: food)
    newest = create(:entry, entry_date: "2026-09-20", category: food)

    get "/api/entries", params: { month: "2026-09" }

    expect(response.parsed_body.pluck("id")).to eq([ newest.id, same_day_second.id, same_day_first.id, old.id ])
  end

  it "レコードが 0 件の月は空配列が返る" do
    get "/api/entries", params: { month: "2026-09" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end

  describe "month の省略" do
    # 当月の判定はサーバーの Asia/Tokyo の日付による。UTC では 8/31 15:30 だが JST では 9/1 0:30
    it "省略すると当月（Asia/Tokyo）が対象になる" do
      current = create(:entry, entry_date: "2026-09-15", category: food)
      create(:entry, entry_date: "2026-08-31", category: food)

      travel_to Time.utc(2026, 8, 31, 15, 30) do
        get "/api/entries"
      end

      expect(response.parsed_body.pluck("id")).to eq([ current.id ])
    end
  end

  describe "month の形式が不正なとき" do
    [ "2026-13", "2026-9", "202609", "2026-09-01", "abc", "" ].each do |month|
      it "#{month.inspect} は 400 になる" do
        get "/api/entries", params: { month: month }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "対象月の形式が不正です",
          "errors" => { "month" => "対象月の形式が不正です" }
        )
      end
    end
  end
end
