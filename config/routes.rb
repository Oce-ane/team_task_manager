Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "auth/register", to: "auth#register"
    post "auth/login", to: "auth#login"

    resources :projects, only: %i[index create show] do
      post :invite, on: :member
      resources :tasks, only: %i[index create]
    end

    resources :tasks, only: %i[update destroy] do
      resources :comments, only: %i[index create]
    end

    resources :comments, only: %i[update destroy]

    resources :notifications, only: :index do
      patch :read, on: :member
      patch :read_all, on: :collection
    end
  end
end
