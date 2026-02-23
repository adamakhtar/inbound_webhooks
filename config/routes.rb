InboundWebhooks::Engine.routes.draw do
  post ":provider", to: "webhooks#create", as: :provider_webhook

  namespace :admin do
    resources :webhooks, only: [ :index, :show ]
  end
end
