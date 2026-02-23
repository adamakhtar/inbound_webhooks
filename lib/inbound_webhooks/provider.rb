module InboundWebhooks
  class Provider
    attr_reader :name, :handlers

    RETRY_DEFAULTS = {
      retry_enabled: true,
      max_retries: 3,
      retry_delay: :exponential
    }.freeze

    CONFIG_DEFAULTS = {
      signature_header: nil,
      signature_algorithm: "sha256",
      secret: nil,
      signature_format: :simple,
      api_key_header: nil,
      api_key: nil,
      event_type_key: nil
    }.freeze

    def initialize(name, **options)
      @name = name.to_sym
      @retry_defaults = {
        retry_enabled: options.delete(:retry_enabled) { RETRY_DEFAULTS[:retry_enabled] },
        max_retries: options.delete(:max_retries) { RETRY_DEFAULTS[:max_retries] },
        retry_delay: options.delete(:retry_delay) { RETRY_DEFAULTS[:retry_delay] }
      }
      @config = CONFIG_DEFAULTS.merge(options)
      @handlers = []
    end

    attr_reader :config

    attr_reader :retry_defaults

    # Explicit: stripe.on "invoice.payment_failed", handler: "InvoiceFailureHandler"
    # Convention: stripe.on "invoice.payment_failed", "charge.succeeded"
    def on(*event_types, handler: nil)
      if handler
        raise ArgumentError, "Provide a single event type when using the handler: keyword" if event_types.size != 1
        register_handler(event_types.first, handler.to_s)
      else
        event_types.each do |event_type|
          raise ArgumentError, "Wildcard event type requires an explicit handler: keyword" if event_type.to_s == "*"
          register_handler(event_type, derive_handler_class(event_type))
        end
      end
    end

    def handler_for(event_type)
      @handlers.find { |h| h.matches?(@name.to_s, event_type) }
    end

    def clear_handlers!
      @handlers = []
    end

    private

    def register_handler(event_type, handler_class)
      @handlers << Handler.new(
        provider: @name.to_s,
        event_type: event_type.to_s,
        handler_class: handler_class,
        retry_defaults: @retry_defaults
      )
    end

    def derive_handler_class(event_type)
      parts = event_type.to_s.split(".")
      class_name = parts.map(&:camelize).join + "Handler"
      "#{@name.to_s.camelize}::#{class_name}"
    end
  end
end
