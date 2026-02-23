require "pagy"
require "inbound_webhooks/version"
require "inbound_webhooks/engine"
require "inbound_webhooks/configuration"
require "inbound_webhooks/provider"
require "inbound_webhooks/handler"

module InboundWebhooks
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def handler_for(provider, event_type)
      provider_obj = configuration.providers[provider.to_sym]
      return nil unless provider_obj

      provider_obj.handler_for(event_type)
    end

    def clear_handlers!
      configuration.providers.each_value(&:clear_handlers!)
    end
  end
end
