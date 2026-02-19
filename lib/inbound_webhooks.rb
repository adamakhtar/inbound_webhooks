require "pagy"
require "inbound_webhooks/version"
require "inbound_webhooks/engine"
require "inbound_webhooks/configuration"
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

    def handler_registry
      @handler_registry ||= []
    end

    def register_handler(provider:, event_type: "*", retry_enabled: true, max_retries: 3, retry_delay: :exponential, &block)
      handler = Handler.new(
        provider: provider,
        event_type: event_type,
        retry_enabled: retry_enabled,
        max_retries: max_retries,
        retry_delay: retry_delay,
        &block
      )
      handler_registry << handler
      handler
    end

    def handler_for(provider, event_type)
      handler_registry.find { |h| h.matches?(provider, event_type) }
    end

    def clear_handlers!
      @handler_registry = []
    end
  end
end
