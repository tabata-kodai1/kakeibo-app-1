class Api::BudgetsController < Api::BaseController
  # 未登録なら作成（201）、登録済みなら上書き（200）。削除する API は持たない
  def update
    budget = Budget.find_or_initialize_by(year_month: params[:year_month])
    created = budget.new_record?
    budget.amount = params.permit(:amount)[:amount]
    raise_bad_request(budget) unless budget.save

    @budget = budget
    render :show, status: created ? :created : :ok
  end
end
