require "rails_helper"

RSpec.describe InboundWebhooks::SignatureVerifier do
  let(:secret) { "test_secret_key" }
  let(:body) { '{"id":"evt_123","type":"payment_intent.succeeded"}' }

  describe "#verify! with simple format" do
    let(:config) do
      {
        signature_header: "HTTP_X_WEBHOOK_SIGNATURE",
        signature_algorithm: "sha256",
        secret: secret,
        signature_format: :simple
      }
    end
    let(:verifier) { described_class.new(config) }

    it "passes with valid signature" do
      expected = OpenSSL::HMAC.hexdigest("sha256", secret, body)
      headers = {"HTTP_X_WEBHOOK_SIGNATURE" => expected}
      expect(verifier.verify!(body, headers)).to be_truthy
    end

    it "passes when signature has algorithm prefix" do
      expected = OpenSSL::HMAC.hexdigest("sha256", secret, body)
      headers = {"HTTP_X_WEBHOOK_SIGNATURE" => "sha256=#{expected}"}
      expect(verifier.verify!(body, headers)).to be_truthy
    end

    it "raises on invalid signature" do
      headers = {"HTTP_X_WEBHOOK_SIGNATURE" => "invalid_signature"}
      expect { verifier.verify!(body, headers) }.to raise_error(
        InboundWebhooks::SignatureVerifier::VerificationFailed, "Invalid signature"
      )
    end

    it "raises on missing header" do
      expect { verifier.verify!(body, {}) }.to raise_error(
        InboundWebhooks::SignatureVerifier::VerificationFailed, "Missing signature header"
      )
    end
  end

  describe "#verify! with timestamped format" do
    let(:config) do
      {
        signature_header: "HTTP_STRIPE_SIGNATURE",
        signature_algorithm: "sha256",
        secret: secret,
        signature_format: :timestamped
      }
    end
    let(:verifier) { described_class.new(config) }

    it "passes with valid timestamped signature" do
      expected = OpenSSL::HMAC.hexdigest("sha256", secret, body)
      header = "t=1234567890,v1=#{expected}"
      headers = {"HTTP_STRIPE_SIGNATURE" => header}
      expect(verifier.verify!(body, headers)).to be_truthy
    end

    it "raises when v1 missing from timestamped header" do
      headers = {"HTTP_STRIPE_SIGNATURE" => "t=1234567890"}
      expect { verifier.verify!(body, headers) }.to raise_error(
        InboundWebhooks::SignatureVerifier::VerificationFailed
      )
    end
  end

  describe "skips verification" do
    it "when no signature_header configured" do
      verifier = described_class.new(signature_header: nil, secret: secret)
      expect(verifier.verify!(body, {})).to be_nil
    end

    it "when no secret configured" do
      verifier = described_class.new(signature_header: "X-Sig", secret: nil)
      expect(verifier.verify!(body, {})).to be_nil
    end
  end
end
