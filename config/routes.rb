Rails.application.routes.draw do
  root "downloads#index"
  resources :downloads, only: [:index, :create, :destroy] do
    post :reprocess, on: :member
  end
  get "search", to: "search#index"
  resource :settings, only: [:edit, :update]
  mount ActionCable.server => "/cable"
end
