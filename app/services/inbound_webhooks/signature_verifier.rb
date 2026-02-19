require "openssl"

module InboundWebhooks
  class SignatureVerifier
    class VerificationFailed < StandardError; end

    def initialize(provider_config)
      @config = provider_config
    end

    def verify!(request_body, headers)
      return unless @config[:signature_header] && @config[:secret]

      header_value = headers[@config[:signature_header]]
      raise VerificationFailed, "Missing signature header" if header_value.blank?

      signature = extract_signature(header_value)
      expected = calculate_hmac(request_body)

      unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
        raise VerificationFailed, "Invalid signature"
      end

      true
    end

    private

    def extract_signature(header_value)
      case @config[:signature_format]
      when :timestamped
        # Stripe-style: "t=timestamp,v1=signature"
        parts = header_value.split(",").each_with_object({}) do |part, hash|
          key, value = part.split("=", 2)
          hash[key.strip] = value&.strip
        end
        parts["v1"] || raise(VerificationFailed, "Missing v1 signature in timestamped header")
      else
        # Simple: raw signature value, strip any algorithm prefix like "sha256="
        header_value.sub(/\Asha\d+=/, "")
      end
    end

    def calculate_hmac(body)
      algorithm = @config[:signature_algorithm] || "sha256"
      digest = OpenSSL::Digest.new(algorithm)
      OpenSSL::HMAC.hexdigest(digest, @config[:secret], body)
    end
  end
end
