require "rails_helper"

RSpec.describe InboundWebhooks::WebhooksController, type: :request do
  let(:secret) { "test_webhook_secret" }
  let(:payload) { { "id" => "evt_123", "type" => "payment_intent.succeeded", "data" => { "amount" => 1000 } } }
  let(:body) { payload.to_json }

  before do
    InboundWebhooks.configure do |config|
      config.provider(:stripe,
        signature_header: "HTTP_X_WEBHOOK_SIGNATURE",
        signature_algorithm: "sha256",
        secret: secret
      )
    end
  end

  def valid_signature(body)
    OpenSSL::HMAC.hexdigest("sha256", secret, body)
  end

  describe "POST /webhooks/:provider" do
    it "accepts valid webhook and enqueues job" do
      expect {
        post "/webhooks/stripe", params: body,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_WEBHOOK_SIGNATURE" => valid_signature(body) }
      }.to change(InboundWebhooks::Webhook, :count).by(1)
        .and have_enqueued_job(InboundWebhooks::ProcessWebhookJob)

      expect(response).to have_http_status(:ok)

      webhook = InboundWebhooks::Webhook.last
      expect(webhook.provider).to eq("stripe")
      expect(webhook.event_type).to eq("payment_intent.succeeded")
      expect(webhook.provider_event_id).to eq("evt_123")
      expect(webhook.payload["data"]["amount"]).to eq(1000)
      expect(webhook.status).to eq("pending")
    end

    it "returns 401 with invalid signature" do
      post "/webhooks/stripe", params: body,
        headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_WEBHOOK_SIGNATURE" => "invalid" }

      expect(response).to have_http_status(:unauthorized)
      expect(InboundWebhooks::Webhook.count).to eq(0)
    end

    it "returns 401 with missing signature" do
      post "/webhooks/stripe", params: body,
        headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for unknown provider" do
      post "/webhooks/unknown", params: body,
        headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end

    context "idempotency" do
      it "skips duplicate provider_event_id" do
        InboundWebhooks::Webhook.create!(
          provider: "stripe", event_type: "payment_intent.succeeded",
          provider_event_id: "evt_123", payload: payload
        )

        expect {
          post "/webhooks/stripe", params: body,
            headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_WEBHOOK_SIGNATURE" => valid_signature(body) }
        }.not_to change(InboundWebhooks::Webhook, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with API key authentication" do
      before do
        InboundWebhooks.reset_configuration!
        InboundWebhooks.configure do |config|
          config.provider(:simple_provider,
            api_key_header: "HTTP_X_API_KEY",
            api_key: "my_secret_key"
          )
        end
      end

      it "accepts valid API key" do
        post "/webhooks/simple_provider", params: body,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_API_KEY" => "my_secret_key" }

        expect(response).to have_http_status(:ok)
      end

      it "rejects invalid API key" do
        post "/webhooks/simple_provider", params: body,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_X_API_KEY" => "wrong_key" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with custom event_type_key" do
      before do
        InboundWebhooks.reset_configuration!
        InboundWebhooks.configure do |config|
          config.provider(:github,
            signature_header: "HTTP_X_HUB_SIGNATURE_256",
            signature_algorithm: "sha256",
            secret: secret,
            event_type_key: "action"
          )
        end
      end

      it "extracts event_type from configured key" do
        github_payload = { "id" => "gh_456", "action" => "opened" }.to_json

        post "/webhooks/github", params: github_payload,
          headers: {
            "CONTENT_TYPE" => "application/json",
            "HTTP_X_HUB_SIGNATURE_256" => valid_signature(github_payload)
          }

        expect(response).to have_http_status(:ok)
        expect(InboundWebhooks::Webhook.last.event_type).to eq("opened")
      end
    end
  end
end
