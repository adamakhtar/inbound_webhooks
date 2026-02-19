require "rails_helper"

RSpec.describe InboundWebhooks::Handler do
  describe "#matches?" do
    it "matches exact provider and event_type" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded") {}
      expect(handler.matches?("stripe", "charge.succeeded")).to be true
    end

    it "does not match different provider" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded") {}
      expect(handler.matches?("github", "charge.succeeded")).to be false
    end

    it "does not match different event_type" do
      handler = described_class.new(provider: "stripe", event_type: "charge.succeeded") {}
      expect(handler.matches?("stripe", "charge.failed")).to be false
    end

    it "matches wildcard event_type" do
      handler = described_class.new(provider: "stripe", event_type: "*") {}
      expect(handler.matches?("stripe", "anything")).to be true
    end
  end

  describe "#call" do
    it "invokes the block with the webhook" do
      received = nil
      handler = described_class.new(provider: "stripe", event_type: "*") { |w| received = w }
      handler.call("webhook_object")
      expect(received).to eq("webhook_object")
    end
  end

  describe "#retry_delay_for" do
    it "returns exponential backoff by default" do
      handler = described_class.new(provider: "stripe", event_type: "*") {}
      expect(handler.retry_delay_for(0)).to eq(5)
      expect(handler.retry_delay_for(1)).to eq(10)
      expect(handler.retry_delay_for(2)).to eq(20)
      expect(handler.retry_delay_for(3)).to eq(40)
    end

    it "returns fixed delay when configured" do
      handler = described_class.new(provider: "stripe", event_type: "*", retry_delay: 60) {}
      expect(handler.retry_delay_for(0)).to eq(60)
      expect(handler.retry_delay_for(3)).to eq(60)
    end
  end
end
