Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: :json } do
    resource :dashboard, only: :show
    resources :issuers, only: [:index, :show]
    resources :bonds, only: :create
    resources :debt_service_payments, only: :update
    resources :shows, only: :index
    resources :list_entries, only: [:create, :update, :destroy]
  end

  # Every non-API path renders the React shell; React Router takes over in the browser.
  get "*path", to: "spa#show", constraints: ->(req) { !req.path.start_with?("/api") }
  root "spa#show"
end
