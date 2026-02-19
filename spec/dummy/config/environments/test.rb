Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecations_treatment = :raise
end
