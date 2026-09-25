require "rails_helper"

# features.md「エラーレスポンス」の共通整形（N-14）。
# 共通処理は ApplicationController にあるため、実在のエンドポイントに例外を起こさせて確かめる。
RSpec.describe "エラーレスポンスの共通整形", type: :request do
  describe "404 Not Found" do
    it "RecordNotFound は 404 と固定メッセージの JSON になる" do
      allow(Entry).to receive(:includes).and_raise(ActiveRecord::RecordNotFound)

      get "/api/entries", params: { month: "2026-09" }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
    end

    it "存在しないパスも 404 の JSON になる" do
      get "/api/unknown"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "対象のレコードが見つかりません")
    end
  end

  describe "500 Internal Server Error" do
    before { allow(Rails.logger).to receive(:error) }

    it "想定外の例外は 500 の JSON になり、例外の内容を含まない" do
      allow(Entry).to receive(:includes).and_raise(StandardError, "secret detail")

      get "/api/entries", params: { month: "2026-09" }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body).to eq("message" => "サーバーエラーが発生しました")
      expect(response.body).not_to include("secret detail")
    end

    it "例外はログに残す" do
      allow(Entry).to receive(:includes).and_raise(StandardError, "boom")

      get "/api/entries", params: { month: "2026-09" }

      expect(Rails.logger).to have_received(:error).with(/StandardError.*boom/m)
    end
  end
end
