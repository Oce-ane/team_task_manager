Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "auth/register", to: "auth#register"
    post "auth/login", to: "auth#login"

    resources :projects, only: %i[index create show] do
      post :invite, on: :member
    end
  end
end
