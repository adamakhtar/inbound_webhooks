Rails.application.routes.draw do
  mount InboundWebhooks::Engine, at: "/webhooks"
end
