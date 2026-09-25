# /api 配下のコントローラの土台。エラーレスポンスの整形（docs/features.md「エラーレスポンス」）をここに集める
class Api::BaseController < ApplicationController
  # 後に書いたものが優先されるため、包括的な StandardError を最初に置く
  rescue_from StandardError, with: :render_internal_server_error
  rescue_from ActiveRecord::RecordNotFound, ActionController::RoutingError, with: :render_not_found
  rescue_from Api::BadRequest, with: :render_bad_request

  private

  def target_month
    TargetMonth.parse(params[:month]) ||
      raise(Api::BadRequest.new("対象月の形式が不正です", errors: { month: "対象月の形式が不正です" }))
  end

  # モデルのバリデーションエラーを 400 にする。errors は項目ごとに先頭のメッセージ 1 件
  def raise_bad_request(record)
    errors = record.errors.to_hash.transform_values(&:first)
    raise Api::BadRequest.new(errors.values.first, errors: errors)
  end

  def render_bad_request(error)
    body = { message: error.message }
    body[:errors] = error.errors if error.errors
    render json: body, status: :bad_request
  end

  def render_not_found(_error)
    render json: { message: "対象のレコードが見つかりません" }, status: :not_found
  end

  # 例外の内容はレスポンスに含めず、ログにだけ残す（N-14）
  def render_internal_server_error(error)
    logger.error("#{error.class}: #{error.message}\n#{error.backtrace&.first(20)&.join("\n")}")
    render json: { message: "サーバーエラーが発生しました" }, status: :internal_server_error
  end
end
