# 本番は画面（S3）と API（EC2）でオリジンが異なるため、CORS が要る（N-12）。
# 許可オリジンは環境変数 ALLOWED_ORIGINS（カンマ区切り）で渡す。
# 開発時は Vite の proxy が /api を転送して CORS を発生させないので、未設定でよい。
module AllowedOrigins
  # 認証を持たない API なので、許可の範囲を広げる書き方は受け付けない。
  # 誤設定に気づけるよう、黙って無視せず起動時に落とす。
  def self.parse(value)
    origins = value.to_s.split(",").map(&:strip).reject(&:empty?)
    if origins.any? { |origin| origin.include?("*") }
      raise ArgumentError, "ALLOWED_ORIGINS にワイルドカード（*）は使えません。許可するオリジンを 1 つずつ指定してください"
    end
    origins
  end
end

allowed_origins = AllowedOrigins.parse(ENV["ALLOWED_ORIGINS"])

# 未設定なら入れない。未設定を例外にすると、環境変数なしで走る
# イメージビルド（assets:precompile）が落ちてしまう。
unless allowed_origins.empty?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)

      # /api 配下だけに適用する（/up などには付けない）。
      # PUT / PATCH / DELETE と content-type: application/json は、ブラウザがプリフライトを送る。
      resource "/api/*",
        headers: :any,
        methods: %i[get post put patch delete options head],
        max_age: 600
    end
  end
end
