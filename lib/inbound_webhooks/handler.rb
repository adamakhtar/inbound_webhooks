module InboundWebhooks
  class Handler
    attr_reader :provider, :event_type, :handler_class

    def initialize(provider:, event_type:, handler_class:, retry_defaults: {})
      @provider = provider.to_s
      @event_type = event_type.to_s
      @handler_class = handler_class.to_s
      @retry_defaults = retry_defaults
    end

    def matches?(provider, event_type)
      return false unless @provider == provider.to_s
      return true if @event_type == "*"

      @event_type == event_type.to_s
    end

    def call(webhook)
      @handler_class.constantize.new.call(webhook)
    end

    def retry_enabled
      resolve_retry_config(:retry_enabled)
    end

    def max_retries
      resolve_retry_config(:max_retries)
    end

    def retry_delay
      resolve_retry_config(:retry_delay)
    end

    def retry_delay_for(attempt)
      case retry_delay
      when :exponential
        (2**attempt) * 5
      when Integer, Float
        retry_delay
      else
        (2**attempt) * 5
      end
    end

    private

    def resolve_retry_config(key)
      klass = @handler_class.constantize
      if klass.respond_to?(key)
        klass.public_send(key)
      else
        @retry_defaults.fetch(key, Provider::RETRY_DEFAULTS[key])
      end
    end
  end
end
