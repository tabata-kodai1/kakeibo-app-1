require "rails_helper"

# N-12 CORS。本番は S3（画面）と EC2（API）でオリジンが異なる。
# 許可オリジンは環境変数 ALLOWED_ORIGINS で渡す。rails_helper が
# "http://allowed.example.com,http://second.example.com" を設定してから Rails を起動している。
RSpec.describe "CORS", type: :request do
  let(:allowed_origin) { "http://allowed.example.com" }
  let(:other_origin) { "http://evil.example.com" }

  describe "実際のリクエスト" do
    it "許可したオリジンには Access-Control-Allow-Origin が付く" do
      get "/api/health", headers: { "Origin" => allowed_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq allowed_origin
    end

    it "カンマ区切りで指定した 2 つ目のオリジンも許可される" do
      get "/api/health", headers: { "Origin" => "http://second.example.com" }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq "http://second.example.com"
    end

    it "許可していないオリジンには Access-Control-Allow-Origin が付かない" do
      get "/api/health", headers: { "Origin" => other_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end

    it "Origin を持たないリクエスト（curl など）には影響しない" do
      get "/api/health"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "プリフライト（OPTIONS）" do
    def preflight(origin, method)
      options "/api/entries/1", headers: {
        "Origin" => origin,
        "Access-Control-Request-Method" => method,
        "Access-Control-Request-Headers" => "content-type"
      }
    end

    %w[PUT PATCH DELETE POST].each do |method|
      it "許可したオリジンからの #{method} + content-type が通る" do
        preflight(allowed_origin, method)

        expect(response).to have_http_status(:ok)
        expect(response.headers["Access-Control-Allow-Origin"]).to eq allowed_origin
        expect(response.headers["Access-Control-Allow-Methods"]).to include(method)
        expect(response.headers["Access-Control-Allow-Headers"]).to match(/content-type/i)
      end
    end

    it "許可していないオリジンには許可のヘッダーが付かない" do
      preflight(other_origin, "PUT")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "適用範囲" do
    it "/api 以外（/up）には CORS のヘッダーを付けない" do
      get "/up", headers: { "Origin" => allowed_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "AllowedOrigins.parse" do
    it "空白と空要素を取り除く" do
      expect(AllowedOrigins.parse(" http://a.example.com , ,http://b.example.com ")).to eq(
        %w[http://a.example.com http://b.example.com]
      )
    end

    it "未設定（nil・空文字）なら空配列を返す" do
      expect(AllowedOrigins.parse(nil)).to eq []
      expect(AllowedOrigins.parse("")).to eq []
    end

    it "ワイルドカード（*）を含む値は拒否する" do
      expect { AllowedOrigins.parse("*") }.to raise_error(ArgumentError, /ワイルドカード/)
      expect { AllowedOrigins.parse("http://a.example.com,http://*.example.com") }
        .to raise_error(ArgumentError, /ワイルドカード/)
    end
  end
end
