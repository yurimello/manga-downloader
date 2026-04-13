Rails.application.routes.draw do
  root "downloads#index"
  resources :downloads, only: [:index, :create, :destroy] do
    post :reprocess, on: :member
  end
  resource :settings, only: [:edit, :update]
  mount ActionCable.server => "/cable"
end
