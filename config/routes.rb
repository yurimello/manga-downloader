Rails.application.routes.draw do
  root "downloads#index"
  resources :downloads, only: [:index, :create, :destroy]
  resource :settings, only: [:edit, :update]
  mount ActionCable.server => "/cable"
end
