# /api 配下で該当するルートがないときの受け皿。既定の HTML／空ボディではなく 404 の JSON にそろえる
class Api::ErrorsController < Api::BaseController
  def not_found
    raise ActionController::RoutingError, "No route matches #{request.path}"
  end
end
