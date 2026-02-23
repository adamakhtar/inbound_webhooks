module InboundWebhooks
  class Configuration
    attr_accessor :providers,
      :admin_base_controller,
      :admin_authentication_required,
      :admin_authentication_method,
      :admin_current_user_method,
      :admin_authorization_required,
      :admin_authorization_method

    def initialize
      @providers = {}
      @admin_base_controller = "::ApplicationController"
      @admin_authentication_required = true
      @admin_authentication_method = :authenticate_user!
      @admin_current_user_method = :current_user
      @admin_authorization_required = true
      @admin_authorization_method = :authorize_user!
    end

    def provider(name, **options)
      provider = Provider.new(name, **options)
      @providers[name.to_sym] = provider
      provider
    end

    def provider_config(name)
      @providers[name.to_sym]&.config
    end
  end
end
