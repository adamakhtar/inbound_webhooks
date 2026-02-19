InboundWebhooks.configure do |config|
  config.admin_authentication_required = true
  config.admin_authentication_method = :authenticate_user!
  config.admin_current_user_method = :current_user
  config.provider(:stripe)
  config.provider(:github)
end
