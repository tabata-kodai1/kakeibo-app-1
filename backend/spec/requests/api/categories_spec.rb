require "rails_helper"

# F-04 の受け入れ条件「GET /api/categories でカテゴリ一覧（収入・支出それぞれ）が取得できること」
RSpec.describe "GET /api/categories", type: :request do
  it "収入・支出の両方のカテゴリが category_type, id 順で返る" do
    salary = create(:category, :income, name: "給与")
    food = create(:category, name: "食費")
    transport = create(:category, name: "交通費")
    bonus = create(:category, :income, name: "賞与")

    get "/api/categories"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([
      { "id" => food.id, "name" => "食費", "category_type" => "EXPENSE" },
      { "id" => transport.id, "name" => "交通費", "category_type" => "EXPENSE" },
      { "id" => salary.id, "name" => "給与", "category_type" => "INCOME" },
      { "id" => bonus.id, "name" => "賞与", "category_type" => "INCOME" }
    ])
  end

  it "カテゴリが 0 件なら空配列が返る" do
    get "/api/categories"

    expect(response.parsed_body).to eq([])
  end
end
