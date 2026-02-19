InboundWebhooks::Engine.routes.draw do
  post ":provider", to: "webhooks#create", as: :provider_webhook
end
