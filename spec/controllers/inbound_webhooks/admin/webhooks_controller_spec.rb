require "rails_helper"

RSpec.describe InboundWebhooks::Admin::WebhooksController, type: :request do
  def create_webhook(**attrs)
    InboundWebhooks::Webhook.create!({
      provider: "stripe",
      event_type: "payment_intent.succeeded",
      payload: { "id" => "evt_1" }
    }.merge(attrs))
  end

  before do
    InboundWebhooks.configure do |config|
      config.provider(:stripe)
      config.provider(:github)
    end
  end

  describe "GET /webhooks/admin/webhooks" do
    it "returns a successful response" do
      get "/webhooks/admin/webhooks"
      expect(response).to have_http_status(:ok)
    end

    it "lists webhooks" do
      create_webhook
      get "/webhooks/admin/webhooks"

      expect(response.body).to include("stripe")
      expect(response.body).to include("payment_intent.succeeded")
    end

    context "filtering by provider" do
      it "shows only matching provider" do
        create_webhook(provider: "stripe")
        create_webhook(provider: "github", event_type: "push")

        get "/webhooks/admin/webhooks", params: { provider: "stripe" }

        expect(response.body).to include("payment_intent.succeeded")
        expect(response.body).not_to include("push")
      end
    end

    context "filtering by statuses" do
      it "shows only matching statuses" do
        create_webhook(status: "pending", event_type: "evt.pending")
        create_webhook(status: "failed", event_type: "evt.failed", error_message: "boom")
        create_webhook(status: "processed", event_type: "evt.processed", processed_at: Time.current)

        get "/webhooks/admin/webhooks", params: { statuses: %w[pending failed] }

        expect(response.body).to include("evt.pending")
        expect(response.body).to include("evt.failed")
        expect(response.body).not_to include("evt.processed")
      end
    end

    context "filtering by created_at preset" do
      it "shows webhooks created within the preset window" do
        recent = create_webhook(event_type: "evt.recent")
        create_webhook(event_type: "evt.old", created_at: 3.days.ago)

        get "/webhooks/admin/webhooks", params: { created_at_preset: "2h" }

        expect(response.body).to include("evt.recent")
        expect(response.body).not_to include("evt.old")
      end
    end

    context "filtering by created_at range" do
      it "shows webhooks within the date range" do
        create_webhook(event_type: "evt.today")
        create_webhook(event_type: "evt.old", created_at: 10.days.ago)

        get "/webhooks/admin/webhooks", params: {
          created_at_from: 1.day.ago.strftime("%Y-%m-%dT%H:%M"),
          created_at_to: Time.current.strftime("%Y-%m-%dT%H:%M")
        }

        expect(response.body).to include("evt.today")
        expect(response.body).not_to include("evt.old")
      end
    end

    context "filtering by processed_at preset" do
      it "shows webhooks processed within the preset window" do
        create_webhook(event_type: "evt.recent_proc", status: "processed", processed_at: 1.hour.ago)
        create_webhook(event_type: "evt.old_proc", status: "processed", processed_at: 5.days.ago)

        get "/webhooks/admin/webhooks", params: { processed_at_preset: "24h" }

        expect(response.body).to include("evt.recent_proc")
        expect(response.body).not_to include("evt.old_proc")
      end
    end

    context "ordering" do
      it "orders by recently processed by default" do
        first = create_webhook(event_type: "evt.first", status: "processed", processed_at: 2.hours.ago)
        second = create_webhook(event_type: "evt.second", status: "processed", processed_at: 1.hour.ago)

        get "/webhooks/admin/webhooks"

        expect(response.body.index("evt.second")).to be < response.body.index("evt.first")
      end

      it "orders by recently created when requested" do
        first = create_webhook(event_type: "evt.older", created_at: 2.hours.ago)
        second = create_webhook(event_type: "evt.newer", created_at: 1.hour.ago)

        get "/webhooks/admin/webhooks", params: { order: "recently_created" }

        expect(response.body.index("evt.newer")).to be < response.body.index("evt.older")
      end
    end

    context "pagination" do
      it "paginates results" do
        30.times { |i| create_webhook(provider_event_id: "evt_#{i}", event_type: "evt.page_#{i}") }

        get "/webhooks/admin/webhooks"

        displayed = (0..29).count { |i| response.body.include?("evt.page_#{i}") }
        expect(displayed).to eq(25)
      end
    end
  end
end
