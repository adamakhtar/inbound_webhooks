InboundWebhooks.configure do |config|
  # ── Admin Dashboard ──────────────────────────────────────────────────
  # config.admin_authentication_required = true
  # config.admin_authentication_method   = :authenticate_user!
  # config.admin_current_user_method     = :current_user
  # config.admin_authorization_required  = true
  # config.admin_authorization_method    = :authorize_user!

  # ── Providers ────────────────────────────────────────────────────────
  # Register a provider for each third-party service that sends you webhooks.
  # Options:
  #   signature_header:    - HTTP header containing the signature (e.g. "Stripe-Signature")
  #   signature_algorithm: - Algorithm used to compute the signature (default: "sha256")
  #   secret:              - Signing secret used to verify payloads
  #   signature_format:    - :simple or :timestamped (default: :simple)
  #   api_key_header:      - HTTP header containing an API key (alternative to signature verification)
  #   api_key:             - Expected API key value
  #   event_type_key:      - JSON key path to the event type in the payload (e.g. "type")
  #
  # stripe = config.provider(:stripe,
  #   signature_header: "Stripe-Signature",
  #   secret: Rails.application.credentials.dig(:stripe, :webhook_secret),
  #   event_type_key: "type"
  # )

  # ── Handlers ─────────────────────────────────────────────────────────
  # Map event types to handler classes. Two styles:
  #
  # 1. Convention-based – derives handler class from provider + event type:
  #    stripe.on "invoice.payment_failed"
  #    # => expects Stripe::InvoicePaymentFailedHandler
  #
  # 2. Explicit – specify the handler class directly:
  #    stripe.on "invoice.payment_failed", handler: "Billing::FailedPaymentHandler"
end
