module InboundWebhooks
  class Configuration
    attr_accessor :providers, :admin_base_controller

    def initialize
      @providers = {}
      @admin_base_controller = "::ApplicationController"
    end

    def provider(name, **options)
      defaults = {
        signature_header: nil,
        signature_algorithm: "sha256",
        secret: nil,
        signature_format: :simple, # :simple or :timestamped (e.g. Stripe)
        api_key_header: nil,
        api_key: nil,
        event_type_key: nil # JSON path to extract event type from payload
      }
      @providers[name.to_sym] = defaults.merge(options)
    end

    def provider_config(name)
      @providers[name.to_sym]
    end
  end
end
