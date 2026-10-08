Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Every non-API path renders the React shell; React Router takes over in the browser.
  get "*path", to: "spa#show", constraints: ->(req) { !req.path.start_with?("/api") }
  root "spa#show"
end
