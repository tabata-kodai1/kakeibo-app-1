require "rails_helper"

# F-07 収支の削除
RSpec.describe "DELETE /api/entries/:id", type: :request do
  let(:food) { create(:category, name: "食費") }
  let!(:entry) { create(:entry, entry_date: "2026-09-25", category: food, amount: 1280) }

  it "204 が返り、レコードが削除される" do
    expect { delete "/api/entries/#{entry.id}" }.to change(Entry, :count).by(-1)

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(Entry.exists?(entry.id)).to be false
  end

  it "対象のレコードだけが削除される" do
    other = create(:entry, entry_date: "2026-09-25", category: food)

    delete "/api/entries/#{entry.id}"

    expect(Entry.pluck(:id)).to eq [ other.id ]
  end

  it "削除後にサマリーとカテゴリ別内訳が再計算される（残額が増える）" do
    create(:budget, year_month: "2026-09", amount: 80_000)

    get "/api/summary", params: { month: "2026-09" }
    expect(response.parsed_body).to include("remaining" => 78_720, "entry_count" => 1)

    delete "/api/entries/#{entry.id}"

    get "/api/summary", params: { month: "2026-09" }
    expect(response.parsed_body).to include("remaining" => 80_000, "expense_total" => 0, "entry_count" => 0, "categories" => [])
  end

  it "カテゴリは削除されない" do
    expect { delete "/api/entries/#{entry.id}" }.not_to change(Category, :count)
  end

  describe "存在しない ID" do
    it "404 が返り、何も削除されない" do
      expect { delete "/api/entries/999999" }.not_to change(Entry, :count)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
    end

    it "すでに削除したレコードを再度削除すると 404 になる" do
      delete "/api/entries/#{entry.id}"
      delete "/api/entries/#{entry.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
