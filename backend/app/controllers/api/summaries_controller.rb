class Api::SummariesController < Api::BaseController
  def show
    @summary = MonthlySummary.new(target_month)
  end
end
