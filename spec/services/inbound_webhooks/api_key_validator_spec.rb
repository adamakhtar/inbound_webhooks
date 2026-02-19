require "rails_helper"

RSpec.describe InboundWebhooks::ApiKeyValidator do
  let(:api_key) { "secret_api_key_123" }

  describe "#validate!" do
    let(:config) { { api_key_header: "HTTP_X_API_KEY", api_key: api_key } }
    let(:validator) { described_class.new(config) }

    it "passes with valid API key" do
      request = double("request", headers: { "HTTP_X_API_KEY" => api_key })
      expect(validator.validate!(request)).to be_truthy
    end

    it "raises on invalid API key" do
      request = double("request", headers: { "HTTP_X_API_KEY" => "wrong_key" })
      expect { validator.validate!(request) }.to raise_error(
        InboundWebhooks::ApiKeyValidator::ValidationFailed, "Invalid API key"
      )
    end

    it "raises on missing API key" do
      request = double("request", headers: {})
      expect { validator.validate!(request) }.to raise_error(
        InboundWebhooks::ApiKeyValidator::ValidationFailed, "Missing API key"
      )
    end
  end

  describe "with multiple API keys (key rotation)" do
    let(:config) { { api_key_header: "HTTP_X_API_KEY", api_key: [ "key_old", "key_new" ] } }
    let(:validator) { described_class.new(config) }

    it "accepts any valid key" do
      request = double("request", headers: { "HTTP_X_API_KEY" => "key_old" })
      expect(validator.validate!(request)).to be_truthy
    end
  end

  describe "skips validation" do
    it "when no api_key_header configured" do
      validator = described_class.new(api_key_header: nil, api_key: api_key)
      request = double("request")
      expect(validator.validate!(request)).to be_nil
    end

    it "when no api_key configured" do
      validator = described_class.new(api_key_header: "X-Key", api_key: nil)
      request = double("request")
      expect(validator.validate!(request)).to be_nil
    end
  end
end
