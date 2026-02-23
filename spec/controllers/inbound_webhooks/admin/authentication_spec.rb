require "rails_helper"

RSpec.describe "Admin authentication", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { User.create!(email: "admin@example.com", password: "password123", admin: true) }

  before do
    InboundWebhooks.configure do |config|
      config.provider(:stripe)
    end

    InboundWebhooks::Webhook.create!(
      provider: "stripe",
      event_type: "payment_intent.succeeded",
      payload: {"id" => "evt_1"}
    )
  end

  context "when admin_authentication_required is true (default)" do
    it "redirects unauthenticated requests" do
      get "/webhooks/admin/webhooks"
      expect(response).to redirect_to("/users/sign_in")
    end

    it "allows authenticated requests" do
      sign_in user
      get "/webhooks/admin/webhooks"
      expect(response).to have_http_status(:ok)
    end

    context "and admin_authentication_method references a nonexistent method" do
      before do
        InboundWebhooks.configuration.admin_authentication_method = :nonexistent_auth_method!
      end

      it "raises a descriptive NoMethodError" do
        expect {
          get "/webhooks/admin/webhooks"
        }.to raise_error(NoMethodError, /admin_authentication_method :nonexistent_auth_method!/)
      end
    end
  end

  context "when admin_authentication_required is false" do
    before do
      InboundWebhooks.configuration.admin_authentication_required = false
      InboundWebhooks.configuration.admin_authorization_required = false
    end

    it "skips authentication entirely" do
      get "/webhooks/admin/webhooks"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#inbound_webhooks_current_user" do
    it "returns the current user via the configured method" do
      sign_in user
      get "/webhooks/admin/webhooks"
      expect(controller.view_assigns).to be_present
    end
  end
end
