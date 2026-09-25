require "rails_helper"

# F-08 検索・絞り込み
RSpec.describe "GET /api/entries（検索）", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:daily) { create(:category, name: "日用品") }

  def ids
    response.parsed_body.pluck("id")
  end

  it "条件を指定しない場合、対象月の全件が返る" do
    a = create(:entry, entry_date: "2026-09-01", category: food)
    b = create(:entry, entry_date: "2026-09-30", category: daily)
    create(:entry, entry_date: "2026-10-01", category: food)

    get "/api/entries", params: { month: "2026-09" }

    expect(ids).to eq [ b.id, a.id ]
  end

  describe "category_id" do
    it "そのカテゴリのレコードだけが返る" do
      target = create(:entry, entry_date: "2026-09-10", category: food)
      create(:entry, entry_date: "2026-09-10", category: daily)

      get "/api/entries", params: { month: "2026-09", category_id: food.id }

      expect(ids).to eq [ target.id ]
    end

    it "存在しないカテゴリを指定すると空配列になる" do
      create(:entry, entry_date: "2026-09-10", category: food)

      get "/api/entries", params: { month: "2026-09", category_id: 999_999 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq []
    end

    it "数値でない指定は 400 になる" do
      get "/api/entries", params: { month: "2026-09", category_id: "abc" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq(
        "message" => "カテゴリの指定が不正です",
        "errors" => { "category_id" => "カテゴリの指定が不正です" }
      )
    end
  end

  describe "keyword" do
    it "メモに部分一致するレコードだけが返る" do
      hit = create(:entry, entry_date: "2026-09-10", category: food, memo: "スーパーで買い物")
      create(:entry, entry_date: "2026-09-10", category: food, memo: "コンビニ")

      get "/api/entries", params: { month: "2026-09", keyword: "スーパー" }

      expect(ids).to eq [ hit.id ]
    end

    it "大文字小文字を区別しない" do
      hit = create(:entry, entry_date: "2026-09-10", category: food, memo: "Amazon で購入")

      get "/api/entries", params: { month: "2026-09", keyword: "amazon" }

      expect(ids).to eq [ hit.id ]
    end

    it "メモが未入力のレコードは一致しない" do
      create(:entry, entry_date: "2026-09-10", category: food, memo: nil)

      get "/api/entries", params: { month: "2026-09", keyword: "a" }

      expect(response.parsed_body).to eq []
    end

    it "% や _ はワイルドカードではなく文字として扱う" do
      hit = create(:entry, entry_date: "2026-09-10", category: food, memo: "50%オフ")
      create(:entry, entry_date: "2026-09-10", category: food, memo: "500円")
      underscore = create(:entry, entry_date: "2026-09-10", category: food, memo: "a_b")
      create(:entry, entry_date: "2026-09-10", category: food, memo: "axb")

      get "/api/entries", params: { month: "2026-09", keyword: "0%" }
      expect(ids).to eq [ hit.id ]

      get "/api/entries", params: { month: "2026-09", keyword: "a_b" }
      expect(ids).to eq [ underscore.id ]
    end

    it "空のキーワードは条件として扱わない" do
      entry = create(:entry, entry_date: "2026-09-10", category: food, memo: nil)

      get "/api/entries", params: { month: "2026-09", keyword: "" }

      expect(ids).to eq [ entry.id ]
    end
  end

  describe "from / to（期間検索）" do
    let!(:aug) { create(:entry, entry_date: "2026-08-31", category: food) }
    let!(:sep_first) { create(:entry, entry_date: "2026-09-01", category: food) }
    let!(:sep_mid) { create(:entry, entry_date: "2026-09-15", category: food) }
    let!(:sep_last) { create(:entry, entry_date: "2026-09-30", category: food) }
    let!(:oct) { create(:entry, entry_date: "2026-10-01", category: food) }

    it "month を無視して期間で絞り込まれる（月をまたげる）" do
      get "/api/entries", params: { month: "2026-01", from: "2026-08-31", to: "2026-10-01" }

      expect(ids).to eq [ oct.id, sep_last.id, sep_mid.id, sep_first.id, aug.id ]
    end

    it "境界日（from と to の当日）を含む" do
      get "/api/entries", params: { from: "2026-09-01", to: "2026-09-30" }

      expect(ids).to eq [ sep_last.id, sep_mid.id, sep_first.id ]
    end

    it "from と to が同じ日なら、その日だけが返る" do
      get "/api/entries", params: { from: "2026-09-15", to: "2026-09-15" }

      expect(ids).to eq [ sep_mid.id ]
    end

    it "from だけの指定は、その日以降が返る（month は無視される）" do
      get "/api/entries", params: { month: "2026-01", from: "2026-09-30" }

      expect(ids).to eq [ oct.id, sep_last.id ]
    end

    it "to だけの指定は、その日以前が返る（month は無視される）" do
      get "/api/entries", params: { month: "2026-12", to: "2026-09-01" }

      expect(ids).to eq [ sep_first.id, aug.id ]
    end

    it "from / to が空文字なら指定なしとして扱い、month で絞り込まれる" do
      get "/api/entries", params: { month: "2026-09", from: "", to: "" }

      expect(ids).to eq [ sep_last.id, sep_mid.id, sep_first.id ]
    end

    it "from が to より後のとき 400 になる" do
      get "/api/entries", params: { from: "2026-09-30", to: "2026-09-01" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["message"]).to eq "開始日は終了日より前の日付を指定してください"
    end

    [ "abc", "2026-9-1", "2026/09/01", "2026-02-30", "2026-13-01" ].each do |value|
      it "from が #{value.inspect} のとき 400 になる" do
        get "/api/entries", params: { from: value }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "開始日の形式が不正です", "errors" => { "from" => "開始日の形式が不正です" }
        )
      end

      it "to が #{value.inspect} のとき 400 になる" do
        get "/api/entries", params: { to: value }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(
          "message" => "終了日の形式が不正です", "errors" => { "to" => "終了日の形式が不正です" }
        )
      end
    end
  end

  describe "複数条件" do
    it "AND で効く" do
      hit = create(:entry, entry_date: "2026-09-10", category: food, memo: "スーパー")
      create(:entry, entry_date: "2026-09-10", category: daily, memo: "スーパー") # カテゴリが違う
      create(:entry, entry_date: "2026-09-10", category: food, memo: "コンビニ") # メモが違う
      create(:entry, entry_date: "2026-08-10", category: food, memo: "スーパー") # 月が違う

      get "/api/entries", params: { month: "2026-09", category_id: food.id, keyword: "スーパー" }

      expect(ids).to eq [ hit.id ]
    end

    it "期間検索でもカテゴリ・キーワードと AND で効く" do
      hit = create(:entry, entry_date: "2026-03-10", category: food, memo: "家賃の一部")
      create(:entry, entry_date: "2026-03-10", category: daily, memo: "家賃の一部")
      create(:entry, entry_date: "2025-12-10", category: food, memo: "家賃の一部")

      get "/api/entries", params: { from: "2026-01-01", to: "2026-09-30", category_id: food.id, keyword: "家賃" }

      expect(ids).to eq [ hit.id ]
    end
  end

  it "一致件数が 0 のとき、空配列が返る" do
    create(:entry, entry_date: "2026-09-10", category: food, memo: "スーパー")

    get "/api/entries", params: { month: "2026-09", keyword: "存在しない" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq []
  end

  describe "該当件数の上限（1,000 件）" do
    def insert_entries(count)
      rows = Array.new(count) { { entry_date: "2026-09-10", category_id: food.id, amount: 100 } }
      Entry.insert_all!(rows)
    end

    it "ちょうど 1,000 件なら返る" do
      insert_entries(1_000)

      get "/api/entries", params: { from: "2026-01-01", to: "2026-12-31" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq 1_000
    end

    it "1,000 件を超えると 400 になり、レコードは 1 件も返らない" do
      insert_entries(1_001)

      get "/api/entries", params: { from: "2026-01-01", to: "2026-12-31" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("message" => "期間が広すぎます。1,000件を超えるため、期間を絞ってください")
    end

    it "絞り込んで 1,000 件以内になれば返る" do
      insert_entries(1_001)
      other = create(:category, name: "その他の支出")
      hit = create(:entry, entry_date: "2026-09-10", category: other)

      get "/api/entries", params: { from: "2026-01-01", to: "2026-12-31", category_id: other.id }

      expect(ids).to eq [ hit.id ]
    end
  end
end
