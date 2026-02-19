module InboundWebhooks
  class ApiKeyValidator
    class ValidationFailed < StandardError; end

    def initialize(provider_config)
      @config = provider_config
    end

    def validate!(request)
      return unless @config[:api_key_header] && @config[:api_key]

      provided_key = extract_api_key(request)
      raise ValidationFailed, "Missing API key" if provided_key.blank?

      expected_keys = Array(@config[:api_key])

      unless expected_keys.any? { |key| ActiveSupport::SecurityUtils.secure_compare(key, provided_key) }
        raise ValidationFailed, "Invalid API key"
      end

      true
    end

    private

    def extract_api_key(request)
      request.headers[@config[:api_key_header]]
    end
  end
end
