require "rails_helper"

RSpec.describe InboundWebhooks::Configuration do
  subject(:config) { described_class.new }

  describe "#provider" do
    it "returns a Provider instance" do
      result = config.provider(:stripe, signature_header: "HTTP_STRIPE_SIGNATURE", secret: "whsec_123")
      expect(result).to be_a(InboundWebhooks::Provider)
      expect(result.name).to eq(:stripe)
    end

    it "stores the provider" do
      config.provider(:stripe)
      expect(config.providers[:stripe]).to be_a(InboundWebhooks::Provider)
    end
  end

  describe "#provider_config" do
    it "returns the provider's config hash" do
      config.provider(:stripe, signature_header: "HTTP_STRIPE_SIGNATURE", secret: "whsec_123")

      result = config.provider_config(:stripe)
      expect(result[:signature_header]).to eq("HTTP_STRIPE_SIGNATURE")
      expect(result[:secret]).to eq("whsec_123")
    end

    it "applies defaults" do
      config.provider(:stripe)

      result = config.provider_config(:stripe)
      expect(result[:signature_algorithm]).to eq("sha256")
      expect(result[:signature_format]).to eq(:simple)
    end

    it "returns nil for unknown provider" do
      expect(config.provider_config(:unknown)).to be_nil
    end
  end
end
