require "rails_helper"

RSpec.describe InboundWebhooks do
  describe ".configure" do
    it "yields configuration" do
      described_class.configure do |config|
        config.provider(:stripe, secret: "test")
      end

      expect(described_class.configuration.provider_config(:stripe)[:secret]).to eq("test")
    end
  end

  describe ".register_handler" do
    it "registers a handler" do
      described_class.register_handler(provider: "stripe", event_type: "charge.succeeded") {}
      expect(described_class.handler_registry.size).to eq(1)
    end

    it "accepts retry configuration" do
      handler = described_class.register_handler(
        provider: "stripe",
        event_type: "charge.succeeded",
        retry_enabled: false,
        max_retries: 5,
        retry_delay: 30
      ) {}

      expect(handler.retry_enabled).to be false
      expect(handler.max_retries).to eq(5)
      expect(handler.retry_delay).to eq(30)
    end
  end

  describe ".handler_for" do
    it "returns exact match over wildcard" do
      described_class.register_handler(provider: "stripe", event_type: "charge.succeeded") {}
      described_class.register_handler(provider: "stripe", event_type: "*") {}

      handler = described_class.handler_for("stripe", "charge.succeeded")
      expect(handler.event_type).to eq("charge.succeeded")
    end

    it "falls back to wildcard handler" do
      described_class.register_handler(provider: "stripe", event_type: "*") {}

      handler = described_class.handler_for("stripe", "charge.failed")
      expect(handler.event_type).to eq("*")
    end

    it "returns nil for unregistered providers" do
      expect(described_class.handler_for("unknown", "event")).to be_nil
    end
  end

  describe ".clear_handlers!" do
    it "empties the registry" do
      described_class.register_handler(provider: "stripe", event_type: "*") {}
      described_class.clear_handlers!
      expect(described_class.handler_registry).to be_empty
    end
  end
end
