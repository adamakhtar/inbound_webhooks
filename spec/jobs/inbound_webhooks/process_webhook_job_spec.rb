require "rails_helper"

RSpec.describe InboundWebhooks::ProcessWebhookJob, type: :job do
  let!(:webhook) do
    InboundWebhooks::Webhook.create!(
      provider: "stripe",
      event_type: "payment_intent.succeeded",
      payload: { "id" => "evt_123", "amount" => 1000 },
      status: "pending"
    )
  end

  describe "#perform" do
    it "processes webhook and marks as processed" do
      received = nil
      InboundWebhooks.register_handler(provider: "stripe", event_type: "payment_intent.succeeded") do |w|
        received = w
      end

      described_class.new.perform(webhook.id)

      expect(received).to eq(webhook)
      expect(webhook.reload.status).to eq("processed")
      expect(webhook.processed_at).to be_present
    end

    it "marks as processed when no handlers registered" do
      described_class.new.perform(webhook.id)

      expect(webhook.reload.status).to eq("processed")
    end

    it "calls wildcard handler" do
      called = false
      InboundWebhooks.register_handler(provider: "stripe", event_type: "*") { |_w| called = true }

      described_class.new.perform(webhook.id)

      expect(called).to be true
    end

    it "prefers exact match over wildcard" do
      calls = []
      InboundWebhooks.register_handler(provider: "stripe", event_type: "payment_intent.succeeded") { calls << :specific }
      InboundWebhooks.register_handler(provider: "stripe", event_type: "*") { calls << :wildcard }

      described_class.new.perform(webhook.id)

      expect(calls).to eq([ :specific ])
    end

    it "skips already processed webhooks" do
      webhook.mark_processed!
      called = false
      InboundWebhooks.register_handler(provider: "stripe", event_type: "*") { called = true }

      described_class.new.perform(webhook.id)

      expect(called).to be false
    end

    it "handles missing webhook gracefully" do
      expect { described_class.new.perform(-1) }.not_to raise_error
    end
  end

  describe "retry behavior" do
    it "retries on failure when retry_enabled" do
      InboundWebhooks.register_handler(
        provider: "stripe", event_type: "payment_intent.succeeded",
        retry_enabled: true, max_retries: 3
      ) { raise "boom" }

      expect {
        described_class.new.perform(webhook.id)
      }.to have_enqueued_job(described_class)

      expect(webhook.reload.retry_count).to eq(1)
      expect(webhook.status).to eq("pending")
      expect(webhook.error_message).to include("boom")
    end

    it "marks as failed when retries exhausted" do
      webhook.update!(retry_count: 2)

      InboundWebhooks.register_handler(
        provider: "stripe", event_type: "payment_intent.succeeded",
        retry_enabled: true, max_retries: 3
      ) { raise "boom" }

      expect {
        described_class.new.perform(webhook.id)
      }.not_to have_enqueued_job(described_class)

      expect(webhook.reload.status).to eq("failed")
    end

    it "marks as failed immediately when retry_enabled is false" do
      InboundWebhooks.register_handler(
        provider: "stripe", event_type: "payment_intent.succeeded",
        retry_enabled: false
      ) { raise "boom" }

      expect {
        described_class.new.perform(webhook.id)
      }.not_to have_enqueued_job(described_class)

      expect(webhook.reload.status).to eq("failed")
      expect(webhook.error_message).to include("boom")
    end
  end
end
