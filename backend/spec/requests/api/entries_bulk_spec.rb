require "rails_helper"

# F-09 一括更新・一括削除
RSpec.describe "/api/entries/bulk", type: :request do
  let(:food) { create(:category, name: "食費") }
  let(:daily) { create(:category, name: "日用品") }
  let(:transport) { create(:category, name: "交通費") }
  let(:salary) { create(:category, :income, name: "給与") }
  let(:bonus) { create(:category, :income, name: "賞与") }

  let!(:e1) { create(:entry, entry_date: "2026-09-01", category: food, amount: 100, memo: "a") }
  let!(:e2) { create(:entry, entry_date: "2026-09-02", category: daily, amount: 200, memo: "b") }
  let!(:e3) { create(:entry, entry_date: "2026-09-03", category: food, amount: 300, memo: "c") }
  let!(:income) { create(:entry, entry_date: "2026-09-04", category: salary, amount: 400_000) }

  def patch_bulk(params)
    patch "/api/entries/bulk", params: params, as: :json
  end

  def delete_bulk(params)
    delete "/api/entries/bulk", params: params, as: :json
  end

  # 更新・削除が 1 件も行われていないことを確かめる
  def snapshot
    Entry.order(:id).pluck(:id, :entry_date, :category_id, :amount, :memo, :updated_at)
  end

  def expect_bad_request(message, errors = nil)
    expect(response).to have_http_status(:bad_request)
    expected = { "message" => message }
    expected["errors"] = errors if errors
    expect(response.parsed_body).to eq(expected)
  end

  describe "PATCH（一括更新）" do
    describe "カテゴリの変更" do
      it "選択した全行のカテゴリが変わり、updated_count が返る" do
        patch_bulk(ids: [ e1.id, e2.id, e3.id ], category_id: transport.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 3)
        expect(Entry.where(id: [ e1.id, e2.id, e3.id ]).pluck(:category_id).uniq).to eq [ transport.id ]
      end

      it "選択していない行は変わらない" do
        patch_bulk(ids: [ e1.id ], category_id: transport.id)

        expect(e2.reload.category_id).to eq daily.id
        expect(income.reload.category_id).to eq salary.id
      end

      it "カテゴリ以外の項目（金額・メモ・日付）は変わらない" do
        patch_bulk(ids: [ e1.id ], category_id: transport.id)

        expect(e1.reload).to have_attributes(amount: 100, memo: "a", entry_date: Date.new(2026, 9, 1))
      end

      it "収入だけを選んで収入カテゴリを指定すれば通る" do
        other_income = create(:entry, entry_date: "2026-09-05", category: salary)

        patch_bulk(ids: [ income.id, other_income.id ], category_id: bonus.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 2)
      end
    end

    describe "日付の変更" do
      it "選択した全行の日付が変わる" do
        patch_bulk(ids: [ e1.id, e2.id ], entry_date: "2026-09-30")

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 2)
        expect(Entry.where(id: [ e1.id, e2.id ]).pluck(:entry_date).uniq).to eq [ Date.new(2026, 9, 30) ]
      end

      it "収入と支出が混在していても、日付だけの変更は通る" do
        patch_bulk(ids: [ e1.id, income.id ], entry_date: "2026-09-30")

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 2)
      end

      it "対象月の外の日付に変更すると、現在の一覧から消える" do
        patch_bulk(ids: [ e1.id, e2.id ], entry_date: "2026-10-05")

        get "/api/entries", params: { month: "2026-09" }
        expect(response.parsed_body.pluck("id")).to contain_exactly(e3.id, income.id)

        get "/api/entries", params: { month: "2026-10" }
        expect(response.parsed_body.pluck("id")).to contain_exactly(e1.id, e2.id)
      end
    end

    it "カテゴリと日付を両方指定できる" do
      patch_bulk(ids: [ e1.id, e3.id ], category_id: transport.id, entry_date: "2026-09-30")

      expect(Entry.where(id: [ e1.id, e3.id ]).pluck(:category_id, :entry_date).uniq).to eq [ [ transport.id, Date.new(2026, 9, 30) ] ]
    end

    it "updated_at が更新される（update_all は自動更新しないため明示している）" do
      travel_to Time.zone.local(2030, 1, 1, 12, 0, 0) do
        patch_bulk(ids: [ e1.id ], entry_date: "2026-09-30")
      end

      expect(e1.reload.updated_at).to be >= Time.zone.local(2030, 1, 1, 12, 0, 0)
      expect(e2.reload.updated_at).to be < Time.zone.local(2030, 1, 1)
    end

    it "更新後にサマリーとカテゴリ別内訳が最新化される" do
      patch_bulk(ids: [ e1.id, e3.id ], category_id: transport.id)

      get "/api/summary", params: { month: "2026-09" }

      expect(response.parsed_body["categories"].pluck("category_name", "amount")).to eq [ [ "交通費", 400 ], [ "日用品", 200 ] ]
    end

    describe "ids の検証（400）" do
      it "空配列は 400 になる" do
        patch_bulk(ids: [], category_id: transport.id)

        expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")
      end

      # [null] は Rails が JSON を読む段階で空配列にするため、未選択と同じ扱いになる
      it "未指定・null・[null] は 400 になる" do
        patch_bulk(ids: [ nil ], category_id: transport.id)
        expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")

        patch_bulk(category_id: transport.id)
        expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")

        patch_bulk(ids: nil, category_id: transport.id)
        expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")
      end

      [
        [ "配列でない（数値）", 1 ],
        [ "配列でない（文字列）", "1" ],
        [ "配列でない（ハッシュ）", { a: 1 } ],
        [ "整数でない要素（文字列）", [ "abc" ] ],
        [ "整数でない要素（小数）", [ 1.5 ] ],
        [ "整数でない要素（配列）", [ [ 1 ] ] ],
        [ "負数の要素", [ -1 ] ]
      ].each do |label, ids|
        it "#{label}は 400 になる" do
          before = snapshot

          patch_bulk(ids: ids, category_id: transport.id)

          expect_bad_request("対象のレコードの指定が不正です", "ids" => "対象のレコードの指定が不正です")
          expect(snapshot).to eq before
        end
      end

      it "数字だけの文字列の要素は整数として受け付ける" do
        patch_bulk(ids: [ e1.id.to_s ], category_id: transport.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 1)
      end

      it "500 件ちょうどは受け付け、501 件は 400 になる" do
        ids = (1..500).to_a
        patch_bulk(ids: ids, category_id: transport.id)
        expect(response).to have_http_status(:not_found) # 上限は超えていない（ID が存在しないので 404）

        patch_bulk(ids: ids + [ 501 ], category_id: transport.id)
        expect_bad_request("一度に操作できるのは500件までです", "ids" => "一度に操作できるのは500件までです")
      end

      it "重複は除いて数える（同じ ID を 2 回送っても 1 件）" do
        patch_bulk(ids: [ e1.id, e1.id, e2.id ], category_id: transport.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 2)
      end

      it "重複を除いて 500 件以内なら、送った件数が 500 を超えていても通る" do
        ids = [ e1.id ] * 501

        patch_bulk(ids: ids, category_id: transport.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("updated_count" => 1)
      end
    end

    describe "更新項目の検証（400）" do
      it "category_id も entry_date も指定がないとき 400 になる" do
        before = snapshot

        patch_bulk(ids: [ e1.id ])

        expect_bad_request("変更する項目を指定してください")
        expect(snapshot).to eq before
      end

      [ [ "不正な形式", "abc" ], [ "実在しない日付", "2026-02-30" ], [ "null", nil ], [ "空文字", "" ] ].each do |label, value|
        it "entry_date が #{label}のとき 400 になり、1 件も更新されない" do
          before = snapshot

          patch_bulk(ids: [ e1.id, e2.id ], entry_date: value)

          expect_bad_request("日付を入力してください", "entry_date" => "日付を入力してください")
          expect(snapshot).to eq before
        end
      end

      it "存在しない category_id のとき 400 になり、1 件も更新されない" do
        before = snapshot

        patch_bulk(ids: [ e1.id, e2.id ], category_id: 999_999)

        expect_bad_request("カテゴリを選択してください", "category_id" => "カテゴリを選択してください")
        expect(snapshot).to eq before
      end

      [ [ "null", nil ], [ "数値でない", "abc" ], [ "ハッシュ", { a: 1 } ] ].each do |label, value|
        it "category_id が #{label}のとき 400 になる" do
          patch_bulk(ids: [ e1.id ], category_id: value)

          expect_bad_request("カテゴリを選択してください", "category_id" => "カテゴリを選択してください")
        end
      end

      it "複数の項目が不正なら、項目ごとにエラーが返る" do
        patch_bulk(ids: [ e1.id ], category_id: 999_999, entry_date: "abc")

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["errors"]).to eq(
          "category_id" => "カテゴリを選択してください", "entry_date" => "日付を入力してください"
        )
      end
    end

    describe "存在しない ID（404）" do
      it "1 件でも含まれると 404 になり、1 件も更新されない" do
        before = snapshot

        patch_bulk(ids: [ e1.id, e2.id, 999_999 ], category_id: transport.id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
        expect(snapshot).to eq before
      end

      it "日付の変更でも、1 件も更新されない" do
        before = snapshot

        patch_bulk(ids: [ e1.id, 999_999 ], entry_date: "2026-09-30")

        expect(response).to have_http_status(:not_found)
        expect(snapshot).to eq before
      end

      it "存在しない ID と不正な category_id を同時に送ると、404 ではなく 400 になる" do
        patch_bulk(ids: [ e1.id, 999_999 ], category_id: 999_999)

        expect(response).to have_http_status(:bad_request)
      end

      it "存在しない ID と収支区分の不一致を同時に送ると、区分より先に 404 になる" do
        patch_bulk(ids: [ e1.id, 999_999 ], category_id: salary.id)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "収支区分をまたぐカテゴリ変更（400）" do
      let(:message) { "支出と収入をまたぐカテゴリ変更はできません" }

      it "選択行に支出と収入が混在しているとき、支出カテゴリを指定しても 400 になり、1 件も更新されない" do
        before = snapshot

        patch_bulk(ids: [ e1.id, income.id ], category_id: transport.id)

        expect_bad_request(message, "category_id" => message)
        expect(snapshot).to eq before
      end

      it "選択行に支出と収入が混在しているとき、収入カテゴリを指定しても 400 になる" do
        before = snapshot

        patch_bulk(ids: [ e1.id, income.id ], category_id: bonus.id)

        expect_bad_request(message, "category_id" => message)
        expect(snapshot).to eq before
      end

      it "支出だけを選んで収入カテゴリを指定すると 400 になる" do
        before = snapshot

        patch_bulk(ids: [ e1.id, e2.id ], category_id: salary.id)

        expect_bad_request(message, "category_id" => message)
        expect(snapshot).to eq before
      end

      it "収入だけを選んで支出カテゴリを指定しても 400 になる" do
        patch_bulk(ids: [ income.id ], category_id: food.id)

        expect_bad_request(message, "category_id" => message)
      end

      it "区分が合わなければ、日付を一緒に指定していても 1 件も更新されない" do
        before = snapshot

        patch_bulk(ids: [ e1.id ], category_id: salary.id, entry_date: "2026-09-30")

        expect(response).to have_http_status(:bad_request)
        expect(snapshot).to eq before
      end
    end
  end

  describe "DELETE（一括削除）" do
    it "1 リクエストで選択した全行が削除され、deleted_count が返る" do
      expect { delete_bulk(ids: [ e1.id, e2.id, e3.id ]) }.to change(Entry, :count).by(-3)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("deleted_count" => 3)
      expect(Entry.pluck(:id)).to eq [ income.id ]
    end

    it "収入と支出が混在していても削除できる" do
      delete_bulk(ids: [ e1.id, income.id ])

      expect(response.parsed_body).to eq("deleted_count" => 2)
    end

    it "DELETE を 1 文で発行する（destroy_all のように件数ぶん発行しない）" do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].start_with?("DELETE") }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        delete_bulk(ids: [ e1.id, e2.id, e3.id ])
      end

      expect(queries.size).to eq 1
    end

    it "カテゴリは削除されない" do
      expect { delete_bulk(ids: [ e1.id, e2.id ]) }.not_to change(Category, :count)
    end

    it "削除後にサマリーが再計算される" do
      delete_bulk(ids: [ e1.id, e2.id, e3.id ])

      get "/api/summary", params: { month: "2026-09" }

      expect(response.parsed_body).to include("expense_total" => 0, "entry_count" => 1, "categories" => [])
    end

    it "重複は除いて数える" do
      delete_bulk(ids: [ e1.id, e1.id ])

      expect(response.parsed_body).to eq("deleted_count" => 1)
    end

    it "存在しない ID が含まれるとき 404 になり、1 件も削除されない" do
      before = snapshot

      delete_bulk(ids: [ e1.id, e2.id, 999_999 ])

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
      expect(snapshot).to eq before
    end

    it "ids が空配列・未指定のとき 400 になる" do
      delete_bulk(ids: [])
      expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")

      delete_bulk({})
      expect_bad_request("対象のレコードを選択してください", "ids" => "対象のレコードを選択してください")
      expect(Entry.count).to eq 4
    end

    it "ids の形式が不正なとき 400 になり、何も削除されない" do
      delete_bulk(ids: [ e1.id, "abc" ])

      expect_bad_request("対象のレコードの指定が不正です", "ids" => "対象のレコードの指定が不正です")
      expect(Entry.count).to eq 4
    end

    it "ids が 501 件以上のとき 400 になる（500 件ちょうどは上限内）" do
      delete_bulk(ids: (1..501).to_a)

      expect_bad_request("一度に操作できるのは500件までです", "ids" => "一度に操作できるのは500件までです")
      expect(Entry.count).to eq 4
    end
  end

  describe "ルーティング" do
    it "/api/entries/bulk が単体の削除（/api/entries/:id）に取られない" do
      delete_bulk(ids: [ e1.id ])

      # 単体の destroy に取られていれば ID "bulk" が見つからず 404 になる
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to have_key("deleted_count")
    end

    it "/api/entries/bulk が単体の更新（PUT /api/entries/:id）に取られない" do
      put "/api/entries/bulk", params: { ids: [ e1.id ], category_id: transport.id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(e1.reload.category_id).to eq food.id
    end

    it "単体の削除（/api/entries/:id）は引き続き使える" do
      delete "/api/entries/#{e1.id}"

      expect(response).to have_http_status(:no_content)
    end
  end
end
