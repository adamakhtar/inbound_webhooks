module InboundWebhooks
  class Handler
    attr_reader :provider, :event_type, :block, :retry_enabled, :max_retries, :retry_delay

    def initialize(provider:, event_type:, retry_enabled: true, max_retries: 3, retry_delay: :exponential, &block)
      @provider = provider.to_s
      @event_type = event_type.to_s
      @retry_enabled = retry_enabled
      @max_retries = max_retries
      @retry_delay = retry_delay
      @block = block
    end

    def matches?(provider, event_type)
      return false unless @provider == provider.to_s
      return true if @event_type == "*"

      @event_type == event_type.to_s
    end

    def call(webhook)
      @block.call(webhook)
    end

    def retry_delay_for(attempt)
      case @retry_delay
      when :exponential
        (2**attempt) * 5 # 5s, 10s, 20s, 40s...
      when Integer, Float
        @retry_delay
      else
        (2**attempt) * 5
      end
    end
  end
end
