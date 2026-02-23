require "rails_helper"

RSpec.describe InboundWebhooks::Handler do
  let(:noop_handler) { Class.new { def call(webhook); end } }

  before { stub_const("NoopHandler", noop_handler) }

  describe "#matches?" do
    it "matches exact provider and event_type" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded", handler_class: "NoopHandler")
      expect(handler.matches?("stripe", "charge.succeeded")).to be true
    end

    it "does not match different provider" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded", handler_class: "NoopHandler")
      expect(handler.matches?("github", "charge.succeeded")).to be false
    end

    it "does not match different event_type" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded", handler_class: "NoopHandler")
      expect(handler.matches?("stripe", "charge.failed")).to be false
    end

    it "matches wildcard event_type" do
      handler = described_class.new(provider: "stripe", event_type: "*", handler_class: "NoopHandler")
      expect(handler.matches?("stripe", "anything")).to be true
    end
  end

  describe "#call" do
    it "instantiates the handler class and invokes call" do
      received = nil
      klass = Class.new do
        define_method(:call) { |w| received = w }
      end
      stub_const("CallTestHandler", klass)

      handler = described_class.new(provider: "stripe", event_type: "*", handler_class: "CallTestHandler")
      handler.call("webhook_object")
      expect(received).to eq("webhook_object")
    end
  end

  describe "retry config resolution" do
    it "uses provider defaults when handler class has no config" do
      handler = described_class.new(
        provider: "stripe", event_type: "*", handler_class: "NoopHandler",
        retry_defaults: { retry_enabled: false, max_retries: 10, retry_delay: 60 }
      )
      expect(handler.retry_enabled).to be false
      expect(handler.max_retries).to eq(10)
      expect(handler.retry_delay).to eq(60)
    end

    it "prefers handler class config over provider defaults" do
      klass = Class.new do
        def call(webhook); end
        def self.retry_enabled = false
        def self.max_retries = 7
        def self.retry_delay = 120
      end
      stub_const("CustomRetryHandler", klass)

      handler = described_class.new(
        provider: "stripe", event_type: "*", handler_class: "CustomRetryHandler",
        retry_defaults: { retry_enabled: true, max_retries: 3, retry_delay: :exponential }
      )
      expect(handler.retry_enabled).to be false
      expect(handler.max_retries).to eq(7)
      expect(handler.retry_delay).to eq(120)
    end

    it "falls back to global defaults when no provider defaults" do
      handler = described_class.new(provider: "stripe", event_type: "*", handler_class: "NoopHandler")
      expect(handler.retry_enabled).to be true
      expect(handler.max_retries).to eq(3)
      expect(handler.retry_delay).to eq(:exponential)
    end
  end

  describe "#retry_delay_for" do
    it "returns exponential backoff by default" do
      handler = described_class.new(provider: "stripe", event_type: "*", handler_class: "NoopHandler")
      expect(handler.retry_delay_for(0)).to eq(5)
      expect(handler.retry_delay_for(1)).to eq(10)
      expect(handler.retry_delay_for(2)).to eq(20)
      expect(handler.retry_delay_for(3)).to eq(40)
    end

    it "returns fixed delay when configured on handler class" do
      klass = Class.new do
        def call(webhook); end
        def self.retry_delay = 60
      end
      stub_const("FixedDelayHandler", klass)

      handler = described_class.new(provider: "stripe", event_type: "*", handler_class: "FixedDelayHandler")
      expect(handler.retry_delay_for(0)).to eq(60)
      expect(handler.retry_delay_for(3)).to eq(60)
    end
  end
end
