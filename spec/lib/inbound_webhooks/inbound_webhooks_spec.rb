require "rails_helper"

RSpec.describe InboundWebhooks do
  let(:noop_handler) { Class.new { def call(w); end } }

  before { stub_const("NoopHandler", noop_handler) }

  describe ".configure" do
    it "yields configuration and registers provider" do
      described_class.configure do |config|
        config.provider(:stripe, secret: "test")
      end

      expect(described_class.configuration.provider_config(:stripe)[:secret]).to eq("test")
    end
  end

  describe ".handler_for" do
    it "returns exact match over wildcard" do
      stub_const("ExactHandler", Class.new { def call(w); end })
      stub_const("WildcardHandler", Class.new { def call(w); end })

      described_class.configure do |config|
        stripe = config.provider(:stripe)
        stripe.on "charge.succeeded", handler: "ExactHandler"
        stripe.on "*", handler: "WildcardHandler"
      end

      handler = described_class.handler_for("stripe", "charge.succeeded")
      expect(handler.handler_class).to eq("ExactHandler")
    end

    it "falls back to wildcard handler" do
      stub_const("WildcardHandler", Class.new { def call(w); end })

      described_class.configure do |config|
        stripe = config.provider(:stripe)
        stripe.on "*", handler: "WildcardHandler"
      end

      handler = described_class.handler_for("stripe", "charge.failed")
      expect(handler.event_type).to eq("*")
    end

    it "returns nil for unregistered providers" do
      expect(described_class.handler_for("unknown", "event")).to be_nil
    end
  end

  describe ".clear_handlers!" do
    it "empties handlers across all providers" do
      described_class.configure do |config|
        stripe = config.provider(:stripe)
        stripe.on "charge.succeeded", handler: "NoopHandler"
      end

      described_class.clear_handlers!
      expect(described_class.handler_for("stripe", "charge.succeeded")).to be_nil
    end
  end
end
