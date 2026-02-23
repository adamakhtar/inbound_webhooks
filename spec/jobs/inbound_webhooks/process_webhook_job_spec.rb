require "rails_helper"

RSpec.describe InboundWebhooks::ProcessWebhookJob, type: :job do
  let!(:webhook) do
    InboundWebhooks::Webhook.create!(
      provider: "stripe",
      event_type: "payment_intent.succeeded",
      payload: {"id" => "evt_123", "amount" => 1000},
      status: "pending"
    )
  end

  def register_handler(event_type, handler_class_name)
    InboundWebhooks.configure do |config|
      stripe = config.provider(:stripe)
      stripe.on event_type, handler: handler_class_name
    end
  end

  describe "#perform" do
    it "processes webhook and marks as processed" do
      klass = Class.new do
        cattr_accessor :last_webhook
        define_method(:call) { |w| self.class.last_webhook = w }
      end
      stub_const("ProcessTestHandler", klass)
      register_handler("payment_intent.succeeded", "ProcessTestHandler")

      described_class.new.perform(webhook.id)

      expect(ProcessTestHandler.last_webhook).to eq(webhook)
      expect(webhook.reload.status).to eq("processed")
      expect(webhook.processed_at).to be_present
    end

    it "marks as unhandled when no handlers registered" do
      InboundWebhooks.configure { |c| c.provider(:stripe) }

      described_class.new.perform(webhook.id)

      expect(webhook.reload.status).to eq("unhandled")
    end

    it "calls wildcard handler" do
      klass = Class.new do
        cattr_accessor :called
        self.called = false
        define_method(:call) { |_w| self.class.called = true }
      end
      stub_const("WildcardTestHandler", klass)
      register_handler("*", "WildcardTestHandler")

      described_class.new.perform(webhook.id)

      expect(WildcardTestHandler.called).to be true
    end

    it "prefers exact match over wildcard" do
      calls = []
      specific_klass = Class.new do
        define_method(:call) { |_w| calls << :specific }
      end
      wildcard_klass = Class.new do
        define_method(:call) { |_w| calls << :wildcard }
      end
      stub_const("SpecificTestHandler", specific_klass)
      stub_const("WildcardTestHandler", wildcard_klass)

      InboundWebhooks.configure do |config|
        stripe = config.provider(:stripe)
        stripe.on "payment_intent.succeeded", handler: "SpecificTestHandler"
        stripe.on "*", handler: "WildcardTestHandler"
      end

      described_class.new.perform(webhook.id)

      expect(calls).to eq([:specific])
    end

    it "skips already processed webhooks" do
      webhook.mark_processed!
      klass = Class.new do
        cattr_accessor :called
        self.called = false
        define_method(:call) { |_w| self.class.called = true }
      end
      stub_const("SkipTestHandler", klass)
      register_handler("*", "SkipTestHandler")

      described_class.new.perform(webhook.id)

      expect(SkipTestHandler.called).to be false
    end

    it "handles missing webhook gracefully" do
      expect { described_class.new.perform(-1) }.not_to raise_error
    end
  end

  describe "retry behavior" do
    it "retries on failure when retry_enabled" do
      klass = Class.new do
        define_method(:call) { |_w| raise "boom" }
      end
      stub_const("FailingHandler", klass)
      register_handler("payment_intent.succeeded", "FailingHandler")

      expect {
        described_class.new.perform(webhook.id)
      }.to have_enqueued_job(described_class)

      expect(webhook.reload.retry_count).to eq(1)
      expect(webhook.status).to eq("retrying")
      expect(webhook.error_message).to include("boom")
    end

    it "marks as failed when retries exhausted" do
      webhook.update!(retry_count: 3, status: "retrying")

      klass = Class.new do
        define_method(:call) { |_w| raise "boom" }
      end
      stub_const("FailingHandler", klass)
      register_handler("payment_intent.succeeded", "FailingHandler")

      expect {
        described_class.new.perform(webhook.id)
      }.not_to have_enqueued_job(described_class)

      expect(webhook.reload.status).to eq("failed")
    end

    it "marks as failed immediately when retry_enabled is false" do
      klass = Class.new do
        def self.retry_enabled = false
        define_method(:call) { |_w| raise "boom" }
      end
      stub_const("NoRetryHandler", klass)
      register_handler("payment_intent.succeeded", "NoRetryHandler")

      expect {
        described_class.new.perform(webhook.id)
      }.not_to have_enqueued_job(described_class)

      expect(webhook.reload.status).to eq("failed")
      expect(webhook.error_message).to include("boom")
    end
  end
end
