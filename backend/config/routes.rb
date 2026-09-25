Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # 疎通確認用。フロントの proxy 経由で API に届いているかをここで確かめる。
  # 本番の API は /api 配下に置くため、この 1 本も同じ前置きにそろえている。
  get "api/health" => "health#show"

  namespace :api, defaults: { format: :json } do
    resources :entries, only: %i[index create]
    resources :categories, only: :index
    resource :summary, only: :show
    put "budgets/:year_month", to: "budgets#update"

    # 該当するルートがない /api/* は 404 の JSON で返す
    match "*unmatched", to: "errors#not_found", via: :all
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
