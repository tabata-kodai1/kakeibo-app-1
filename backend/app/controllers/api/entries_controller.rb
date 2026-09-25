class Api::EntriesController < Api::BaseController
  def index
    @entries = Entry.includes(:category).in_month(target_month).newest_first
  end
end
