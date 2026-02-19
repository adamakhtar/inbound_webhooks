require "rails_helper"

RSpec.describe InboundWebhooks::Webhook, type: :model do
  def build_webhook(**overrides)
    InboundWebhooks::Webhook.new(
      { provider: "stripe", event_type: "payment_intent.succeeded", payload: { "id" => "evt_123" } }.merge(overrides)
    )
  end

  describe "validations" do
    it "is valid with required attributes" do
      expect(build_webhook).to be_valid
    end

    it "requires provider" do
      expect(build_webhook(provider: nil)).not_to be_valid
    end

    it "requires event_type" do
      expect(build_webhook(event_type: nil)).not_to be_valid
    end

    it "requires payload" do
      expect(build_webhook(payload: nil)).not_to be_valid
    end

    it "validates status inclusion" do
      expect(build_webhook(status: "invalid")).not_to be_valid
    end
  end

  describe "scopes" do
    before do
      InboundWebhooks::Webhook.create!(provider: "stripe", event_type: "charge.succeeded", payload: { "id" => "1" }, status: "pending")
      InboundWebhooks::Webhook.create!(provider: "github", event_type: "push", payload: { "id" => "2" }, status: "processed")
      InboundWebhooks::Webhook.create!(provider: "stripe", event_type: "charge.failed", payload: { "id" => "3" }, status: "failed")
    end

    it "filters by provider" do
      expect(InboundWebhooks::Webhook.by_provider("stripe").count).to eq(2)
    end

    it "filters by event_type" do
      expect(InboundWebhooks::Webhook.by_event_type("push").count).to eq(1)
    end

    it "filters pending" do
      expect(InboundWebhooks::Webhook.pending.count).to eq(1)
    end

    it "filters processed" do
      expect(InboundWebhooks::Webhook.processed.count).to eq(1)
    end

    it "filters failed" do
      expect(InboundWebhooks::Webhook.failed.count).to eq(1)
    end
  end

  describe "status transitions" do
    let(:webhook) { build_webhook.tap(&:save!) }

    it ".claim_for_processing! from pending" do
      result = InboundWebhooks::Webhook.claim_for_processing!(webhook.id)
      expect(result).to be_a(InboundWebhooks::Webhook)
      expect(result.status).to eq("processing")
    end

    it ".claim_for_processing! from failed" do
      webhook.mark_failed!("error")
      result = InboundWebhooks::Webhook.claim_for_processing!(webhook.id)
      expect(result).to be_a(InboundWebhooks::Webhook)
      expect(result.status).to eq("processing")
    end

    it ".claim_for_processing! returns nil when already processing" do
      InboundWebhooks::Webhook.claim_for_processing!(webhook.id)
      expect(InboundWebhooks::Webhook.claim_for_processing!(webhook.id)).to be_nil
    end

    it ".claim_for_processing! returns nil when already processed" do
      InboundWebhooks::Webhook.claim_for_processing!(webhook.id)
      webhook.reload.mark_processed!
      expect(InboundWebhooks::Webhook.claim_for_processing!(webhook.id)).to be_nil
    end

    it ".claim_for_processing! returns nil for nonexistent id" do
      expect(InboundWebhooks::Webhook.claim_for_processing!(-1)).to be_nil
    end

    it "#mark_processed!" do
      webhook.mark_processed!
      expect(webhook.reload.status).to eq("processed")
      expect(webhook.processed_at).to be_present
    end

    it "#mark_failed! with exception" do
      webhook.mark_failed!(StandardError.new("boom"))
      expect(webhook.reload.status).to eq("failed")
      expect(webhook.error_message).to include("boom")
    end

    it "#mark_failed! with string" do
      webhook.mark_failed!("something went wrong")
      expect(webhook.reload.error_message).to eq("something went wrong")
    end

    it "#increment_retry!" do
      expect { webhook.increment_retry! }.to change { webhook.reload.retry_count }.by(1)
    end
  end

  describe "status predicates" do
    it "#pending?" do
      expect(build_webhook(status: "pending")).to be_pending
    end

    it "#processed?" do
      expect(build_webhook(status: "processed")).to be_processed
    end

    it "#failed?" do
      expect(build_webhook(status: "failed")).to be_failed
    end
  end
end
