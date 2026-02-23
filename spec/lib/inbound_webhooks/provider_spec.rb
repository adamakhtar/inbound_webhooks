require "rails_helper"

RSpec.describe InboundWebhooks::Provider do
  subject(:provider) { described_class.new(:stripe, secret: "whsec_123") }

  describe "#config" do
    it "merges options with defaults" do
      expect(provider.config[:secret]).to eq("whsec_123")
      expect(provider.config[:signature_algorithm]).to eq("sha256")
      expect(provider.config[:signature_format]).to eq(:simple)
    end

    it "does not include retry keys in config" do
      p = described_class.new(:stripe, retry_enabled: false, max_retries: 5)
      expect(p.config).not_to have_key(:retry_enabled)
      expect(p.config).not_to have_key(:max_retries)
    end
  end

  describe "#retry_defaults" do
    it "uses global defaults when none specified" do
      expect(provider.retry_defaults[:retry_enabled]).to be true
      expect(provider.retry_defaults[:max_retries]).to eq(3)
      expect(provider.retry_defaults[:retry_delay]).to eq(:exponential)
    end

    it "accepts custom retry defaults" do
      p = described_class.new(:stripe, retry_enabled: false, max_retries: 10, retry_delay: 30)
      expect(p.retry_defaults[:retry_enabled]).to be false
      expect(p.retry_defaults[:max_retries]).to eq(10)
      expect(p.retry_defaults[:retry_delay]).to eq(30)
    end
  end

  describe "#on" do
    context "with explicit handler" do
      it "registers a handler for a single event type" do
        provider.on "charge.succeeded", handler: "ChargeHandler"
        expect(provider.handlers.size).to eq(1)
        expect(provider.handlers.first.handler_class).to eq("ChargeHandler")
        expect(provider.handlers.first.event_type).to eq("charge.succeeded")
      end

      it "raises when multiple event types given with handler keyword" do
        expect {
          provider.on "a", "b", handler: "X"
        }.to raise_error(ArgumentError, /single event type/)
      end

      it "registers wildcard with explicit handler" do
        provider.on "*", handler: "Stripe::CatchAllHandler"
        expect(provider.handlers.first.event_type).to eq("*")
      end
    end

    context "with convention-based handlers" do
      it "derives handler class from provider name and event type" do
        provider.on "invoice.payment_failed"
        expect(provider.handlers.first.handler_class).to eq("Stripe::InvoicePaymentFailedHandler")
      end

      it "registers multiple event types" do
        provider.on "charge.succeeded", "charge.failed"
        expect(provider.handlers.map(&:handler_class)).to eq([
          "Stripe::ChargeSucceededHandler",
          "Stripe::ChargeFailedHandler"
        ])
      end

      it "raises for wildcard without explicit handler" do
        expect {
          provider.on "*"
        }.to raise_error(ArgumentError, /Wildcard/)
      end
    end
  end

  describe "#handler_for" do
    before do
      stub_const("ExactHandler", Class.new {
        def call(w)
        end
      })
      stub_const("WildcardHandler", Class.new {
        def call(w)
        end
      })
    end

    it "returns exact match" do
      provider.on "charge.succeeded", handler: "ExactHandler"
      handler = provider.handler_for("charge.succeeded")
      expect(handler.handler_class).to eq("ExactHandler")
    end

    it "returns wildcard match" do
      provider.on "*", handler: "WildcardHandler"
      handler = provider.handler_for("anything")
      expect(handler.event_type).to eq("*")
    end

    it "prefers exact over wildcard (registration order)" do
      provider.on "charge.succeeded", handler: "ExactHandler"
      provider.on "*", handler: "WildcardHandler"
      handler = provider.handler_for("charge.succeeded")
      expect(handler.handler_class).to eq("ExactHandler")
    end

    it "returns nil for unregistered event" do
      expect(provider.handler_for("unknown.event")).to be_nil
    end
  end

  describe "#clear_handlers!" do
    it "removes all handlers" do
      provider.on "charge.succeeded", handler: "ExactHandler"
      provider.clear_handlers!
      expect(provider.handlers).to be_empty
    end
  end
end
