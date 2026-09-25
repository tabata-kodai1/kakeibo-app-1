class Api::CategoriesController < Api::BaseController
  def index
    @categories = Category.order(:category_type, :id)
  end
end
