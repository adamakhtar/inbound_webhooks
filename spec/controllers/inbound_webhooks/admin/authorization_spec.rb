require "rails_helper"

RSpec.describe "Admin authorization", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:webhook) do
    InboundWebhooks::Webhook.create!(
      provider: "stripe",
      event_type: "payment_intent.succeeded",
      payload: { "id" => "evt_1" }
    )
  end

  before do
    InboundWebhooks.configure do |config|
      config.provider(:stripe)
      config.admin_authorization_method = :authorize_user!
    end

    webhook
  end

  context "when admin_authorization_required is true (default)" do
    context "and user is authorized" do
      let(:user) { User.create!(email: "admin@example.com", password: "password123", admin: true) }

      it "allows access" do
        sign_in user
        get "/webhooks/admin/webhooks"
        expect(response).to have_http_status(:ok)
      end
    end

    context "and user is not authorized" do
      let(:user) { User.create!(email: "user@example.com", password: "password123", admin: false) }

      it "denies access" do
        sign_in user
        get "/webhooks/admin/webhooks"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "and admin_authorization_method references a nonexistent method" do
      before do
        InboundWebhooks.configuration.admin_authorization_method = :nonexistent_auth_method!
      end

      it "raises a descriptive NoMethodError" do
        user = User.create!(email: "admin@example.com", password: "password123", admin: true)
        sign_in user
        expect {
          get "/webhooks/admin/webhooks"
        }.to raise_error(NoMethodError, /admin_authorization_method :nonexistent_auth_method!/)
      end
    end
  end

  context "when admin_authorization_required is false" do
    before do
      InboundWebhooks.configuration.admin_authorization_required = false
    end

    it "skips authorization entirely" do
      user = User.create!(email: "user@example.com", password: "password123", admin: false)
      sign_in user
      get "/webhooks/admin/webhooks"
      expect(response).to have_http_status(:ok)
    end
  end
end
