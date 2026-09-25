require "rails_helper"

# F-05 収支の追加
RSpec.describe "POST /api/entries", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:salary) { create(:category, :income, name: "給与") }

  let(:valid_params) do
    { entry_date: "2026-09-25", category_id: food.id, amount: 1280, memo: "スーパーで買い物" }
  end

  def post_entry(params)
    post "/api/entries", params: params, as: :json
  end

  describe "正しい値を送ったとき" do
    it "201 が返り、作成したレコードが F-05 の形式で返る" do
      expect { post_entry(valid_params) }.to change(Entry, :count).by(1)

      created = Entry.last
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(
        "id" => created.id,
        "entry_date" => "2026-09-25",
        "category_id" => food.id,
        "category_name" => "食費",
        "category_type" => "EXPENSE",
        "amount" => 1280,
        "memo" => "スーパーで買い物"
      )
    end

    it "収入カテゴリなら category_type が INCOME で返る" do
      post_entry(valid_params.merge(category_id: salary.id, amount: 250_000))

      expect(response.parsed_body).to include("category_name" => "給与", "category_type" => "INCOME")
    end

    it "メモは省略できる（null で保存される）" do
      post_entry(valid_params.except(:memo))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["memo"]).to be_nil
    end

    it "空白のみのメモは未入力として null で保存される" do
      post_entry(valid_params.merge(memo: "  　 "))

      expect(response).to have_http_status(:created)
      expect(Entry.last.memo).to be_nil
    end

    it "未来日付も登録できる" do
      post_entry(valid_params.merge(entry_date: "2099-01-01"))

      expect(response).to have_http_status(:created)
      expect(Entry.last.entry_date).to eq Date.new(2099, 1, 1)
    end

    it "金額の下限（1）・上限（9,999,999）ちょうどは登録できる" do
      post_entry(valid_params.merge(amount: 1))
      expect(response).to have_http_status(:created)

      post_entry(valid_params.merge(amount: 9_999_999))
      expect(response).to have_http_status(:created)
    end

    it "数字だけの文字列（\"1280\"）の金額は整数として登録される" do
      post_entry(valid_params.merge(amount: "1280"))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["amount"]).to eq 1280
    end

    it "メモが 200 文字ちょうどなら登録できる" do
      post_entry(valid_params.merge(memo: "あ" * 200))

      expect(response).to have_http_status(:created)
    end
  end

  describe "一覧・サマリーへの反映" do
    it "追加後にサマリーとカテゴリ別内訳が再計算される（残額が減る）" do
      create(:budget, year_month: "2026-09", amount: 80_000)

      get "/api/summary", params: { month: "2026-09" }
      expect(response.parsed_body).to include("remaining" => 80_000, "expense_total" => 0, "categories" => [])

      post_entry(valid_params)

      get "/api/summary", params: { month: "2026-09" }
      expect(response.parsed_body).to include(
        "remaining" => 78_720, "expense_total" => 1_280, "entry_count" => 1
      )
      expect(response.parsed_body["categories"]).to eq([
        { "category_id" => food.id, "category_name" => "食費", "amount" => 1_280, "rate" => 100 }
      ])
    end

    it "登録したレコードは、その月の一覧にだけ現れる" do
      post_entry(valid_params.merge(entry_date: "2026-10-03"))
      created_id = response.parsed_body["id"]

      get "/api/entries", params: { month: "2026-09" }
      expect(response.parsed_body).to eq []

      get "/api/entries", params: { month: "2026-10" }
      expect(response.parsed_body.pluck("id")).to eq [ created_id ]
    end
  end

  describe "バリデーション（400）" do
    def expect_bad_request(errors)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq(errors)
      expect(response.parsed_body["message"]).to eq(errors.values.first)
    end

    it "何も登録されない" do
      expect { post_entry(valid_params.merge(amount: 0)) }.not_to change(Entry, :count)
    end

    describe "entry_date" do
      [ [ "未入力", nil ], [ "空文字", "" ], [ "不正な形式", "abc" ], [ "実在しない日付", "2026-02-30" ] ].each do |label, value|
        it "#{label}は 400 になる" do
          post_entry(valid_params.merge(entry_date: value))

          expect_bad_request("entry_date" => "日付を入力してください")
        end
      end

      it "キーがなくても 400 になる" do
        post_entry(valid_params.except(:entry_date))

        expect_bad_request("entry_date" => "日付を入力してください")
      end
    end

    describe "category_id" do
      it "未入力は 400 になる" do
        post_entry(valid_params.merge(category_id: nil))

        expect_bad_request("category_id" => "カテゴリを選択してください")
      end

      it "存在しない ID は 400 になる" do
        post_entry(valid_params.merge(category_id: 999_999))

        expect_bad_request("category_id" => "カテゴリを選択してください")
      end
    end

    describe "amount" do
      {
        "未入力" => nil,
        "0" => 0,
        "負数" => -100,
        "小数" => 12.5,
        "文字列" => "abc",
        "カンマ付き文字列" => "1,280",
        "上限（9,999,999）超え" => 10_000_000
      }.each do |label, value|
        it "#{label}は 400 になる" do
          post_entry(valid_params.merge(amount: value))

          expect_bad_request("amount" => "金額は1以上の整数で入力してください")
        end
      end

      it "キーがなくても 400 になる" do
        post_entry(valid_params.except(:amount))

        expect_bad_request("amount" => "金額は1以上の整数で入力してください")
      end

      it "ハッシュや配列で送られても 400 になる" do
        post_entry(valid_params.merge(amount: { value: 100 }))
        expect_bad_request("amount" => "金額は1以上の整数で入力してください")

        post_entry(valid_params.merge(amount: [ 100 ]))
        expect_bad_request("amount" => "金額は1以上の整数で入力してください")
      end
    end

    describe "memo" do
      it "201 文字以上は 400 になる" do
        post_entry(valid_params.merge(memo: "あ" * 201))

        expect_bad_request("memo" => "メモは200文字以内で入力してください")
      end

      it "改行を含むと 400 になる" do
        post_entry(valid_params.merge(memo: "1行目\n2行目"))

        expect_bad_request("memo" => "メモに改行は含められません")
      end
    end

    it "複数の項目が不正なら、項目ごとにエラーが返る" do
      post_entry(valid_params.merge(entry_date: nil, amount: 0))

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to eq(
        "entry_date" => "日付を入力してください",
        "amount" => "金額は1以上の整数で入力してください"
      )
    end
  end

  it "id や created_at など、指定できない項目は無視される" do
    post_entry(valid_params.merge(id: 999, created_at: "2000-01-01T00:00:00Z"))

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["id"]).not_to eq 999
    expect(Entry.last.created_at.year).to be >= Time.current.year
  end
end
