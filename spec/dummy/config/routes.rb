Rails.application.routes.draw do
  devise_for :users
  mount InboundWebhooks::Engine, at: "/webhooks"
end
