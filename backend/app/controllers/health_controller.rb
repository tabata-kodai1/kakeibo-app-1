class HealthController < ApplicationController
  # 疎通確認用。DB まで届いているかも含めて確かめたいので、接続を 1 度叩く。
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: { status: "ok", database: "connected" }
  end
end
