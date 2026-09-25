require "rails_helper"

# F-06 収支の編集
RSpec.describe "PUT /api/entries/:id", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:daily) { create(:category, name: "日用品") }
  let(:salary) { create(:category, :income, name: "給与") }
  let(:bonus) { create(:category, :income, name: "賞与") }
  let!(:entry) { create(:entry, entry_date: "2026-09-25", category: food, amount: 1280, memo: "元のメモ") }

  let(:valid_params) do
    { entry_date: "2026-09-26", category_id: daily.id, amount: 1500, memo: "訂正" }
  end

  def put_entry(id, params)
    put "/api/entries/#{id}", params: params, as: :json
  end

  describe "正しい値を送ったとき" do
    it "200 が返り、更新後のレコードが返る" do
      put_entry(entry.id, valid_params)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "id" => entry.id,
        "entry_date" => "2026-09-26",
        "category_id" => daily.id,
        "category_name" => "日用品",
        "category_type" => "EXPENSE",
        "amount" => 1500,
        "memo" => "訂正"
      )
      expect(entry.reload).to have_attributes(entry_date: Date.new(2026, 9, 26), category_id: daily.id, amount: 1500, memo: "訂正")
    end

    it "レコードは増えない" do
      expect { put_entry(entry.id, valid_params) }.not_to change(Entry, :count)
    end

    it "updated_at が更新される" do
      travel_to Time.zone.local(2030, 1, 1, 12, 0, 0) do
        put_entry(entry.id, valid_params)
      end

      expect(entry.reload.updated_at).to be >= Time.zone.local(2030, 1, 1, 12, 0, 0)
    end

    it "値が変わらない更新も 200 になる" do
      put_entry(entry.id, entry_date: "2026-09-25", category_id: food.id, amount: 1280, memo: "元のメモ")

      expect(response).to have_http_status(:ok)
    end

    it "メモを省略すると null に置き換わる（全置換）" do
      put_entry(entry.id, valid_params.except(:memo))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["memo"]).to be_nil
      expect(entry.reload.memo).to be_nil
    end

    it "同じ収支区分のカテゴリへの変更は通る（収入どうし）" do
      income = create(:entry, entry_date: "2026-09-25", category: salary, amount: 200_000)

      put_entry(income.id, entry_date: "2026-09-25", category_id: bonus.id, amount: 200_000)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("category_name" => "賞与", "category_type" => "INCOME")
    end
  end

  describe "収支区分をまたぐカテゴリ変更" do
    it "支出のレコードに収入カテゴリを指定すると 400 になり、更新されない" do
      put_entry(entry.id, valid_params.merge(category_id: salary.id))

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq(
        "message" => "支出と収入をまたぐカテゴリ変更はできません",
        "errors" => { "category_id" => "支出と収入をまたぐカテゴリ変更はできません" }
      )
      expect(entry.reload).to have_attributes(category_id: food.id, amount: 1280, memo: "元のメモ")
    end

    it "収入のレコードに支出カテゴリを指定しても 400 になる" do
      income = create(:entry, entry_date: "2026-09-25", category: salary, amount: 200_000)

      put_entry(income.id, entry_date: "2026-09-25", category_id: food.id, amount: 200_000)

      expect(response).to have_http_status(:bad_request)
      expect(income.reload.category_id).to eq salary.id
    end

    it "存在しない category_id は区分の比較をせず、カテゴリ未選択と同じ 400 になる" do
      put_entry(entry.id, valid_params.merge(category_id: 999_999))

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq("category_id" => "カテゴリを選択してください")
    end
  end

  describe "一覧・サマリーへの反映" do
    it "更新後にサマリーとカテゴリ別内訳が再計算される" do
      create(:budget, year_month: "2026-09", amount: 80_000)
      put_entry(entry.id, valid_params)

      get "/api/summary", params: { month: "2026-09" }

      expect(response.parsed_body).to include("expense_total" => 1500, "remaining" => 78_500)
      expect(response.parsed_body["categories"]).to eq([
        { "category_id" => daily.id, "category_name" => "日用品", "amount" => 1500, "rate" => 100 }
      ])
    end

    it "日付を別の月に変更すると、元の月の一覧から消え、移動先の月に現れる" do
      put_entry(entry.id, valid_params.merge(entry_date: "2026-10-05"))

      get "/api/entries", params: { month: "2026-09" }
      expect(response.parsed_body).to eq []

      get "/api/entries", params: { month: "2026-10" }
      expect(response.parsed_body.pluck("id")).to eq [ entry.id ]
    end
  end

  describe "バリデーション（400）" do
    it "F-05 と同じ検証が効き、更新されない" do
      put_entry(entry.id, valid_params.merge(amount: 0))

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq("amount" => "金額は1以上の整数で入力してください")
      expect(entry.reload.amount).to eq 1280
    end

    it "必須項目が欠けていれば 400 になる（部分更新は持たない）" do
      put_entry(entry.id, { memo: "メモだけ" })

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"].keys).to contain_exactly("entry_date", "category_id", "amount")
      expect(entry.reload.memo).to eq "元のメモ"
    end

    it "メモが 201 文字以上、改行を含む、日付が不正のときも 400 になる" do
      put_entry(entry.id, valid_params.merge(memo: "あ" * 201))
      expect(response.parsed_body["errors"]).to eq("memo" => "メモは200文字以内で入力してください")

      put_entry(entry.id, valid_params.merge(memo: "a\nb"))
      expect(response.parsed_body["errors"]).to eq("memo" => "メモに改行は含められません")

      put_entry(entry.id, valid_params.merge(entry_date: "2026-02-30"))
      expect(response.parsed_body["errors"]).to eq("entry_date" => "日付を入力してください")
    end
  end

  it "PATCH では更新できない（設計書は PUT のみ。PATCH は一括更新の /entries/bulk 用）" do
    patch "/api/entries/#{entry.id}", params: valid_params, as: :json

    expect(response).to have_http_status(:not_found)
    expect(entry.reload.amount).to eq 1280
  end

  describe "存在しない ID" do
    it "404 が返る" do
      put_entry(999_999, valid_params)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
    end

    it "数値でない ID も 404 になる" do
      put_entry("abc", valid_params)

      expect(response).to have_http_status(:not_found)
    end

    it "不正な値を送っても、ID の確認が先なので 404 になる" do
      put_entry(999_999, valid_params.merge(amount: 0))

      expect(response).to have_http_status(:not_found)
    end
  end
end
