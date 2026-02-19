InboundWebhooks.configure do |config|
  config.provider(:stripe)
  config.provider(:github)
end
