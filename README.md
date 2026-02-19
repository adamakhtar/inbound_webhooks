# InboundWebhooks

A mountable Rails engine for accepting, authenticating, storing, and asynchronously processing inbound webhooks from any provider.

## Features

- **Generic provider support** — define handlers for any webhook provider
- **Authentication** — HMAC signature verification and API key validation
- **Persistent storage** — all webhooks saved to DB before processing
- **Async processing** — webhooks processed via ActiveJob background jobs
- **Configurable retries** — per-handler retry settings with exponential backoff
- **Idempotency** — duplicate webhooks detected by provider event ID

## Installation

Add to your Gemfile:

```ruby
gem "inbound_webhooks", path: "path/to/inbound_webhooks"
```

Run the installation:

```bash
bundle install
bin/rails inbound_webhooks:install:migrations
bin/rails db:migrate
```

Mount the engine in `config/routes.rb`:

```ruby
mount InboundWebhooks::Engine, at: "/webhooks"
```

This exposes `POST /webhooks/:provider` for all configured providers.

## Configuration

Configure providers in an initializer:

```ruby
# config/initializers/inbound_webhooks.rb

InboundWebhooks.configure do |config|
  # Stripe — HMAC signature with timestamped format
  config.provider(:stripe,
    signature_header: "HTTP_STRIPE_SIGNATURE",
    signature_algorithm: "sha256",
    signature_format: :timestamped,
    secret: ENV["STRIPE_WEBHOOK_SECRET"],
    event_type_key: "type"
  )

  # GitHub — HMAC signature with simple format
  config.provider(:github,
    signature_header: "HTTP_X_HUB_SIGNATURE_256",
    signature_algorithm: "sha256",
    secret: ENV["GITHUB_WEBHOOK_SECRET"],
    event_type_key: "action"
  )

  # Simple provider — API key only
  config.provider(:acme,
    api_key_header: "HTTP_X_API_KEY",
    api_key: ENV["ACME_WEBHOOK_API_KEY"]
  )
end
```

### Provider Options

| Option | Default | Description |
|---|---|---|
| `signature_header` | `nil` | Request header containing the HMAC signature |
| `signature_algorithm` | `"sha256"` | HMAC algorithm (`sha256` or `sha1`) |
| `signature_format` | `:simple` | `:simple` or `:timestamped` (Stripe-style `t=...,v1=...`) |
| `secret` | `nil` | Shared secret for HMAC computation |
| `api_key_header` | `nil` | Request header containing the API key |
| `api_key` | `nil` | Expected API key (string or array for key rotation) |
| `event_type_key` | `nil` | JSON key to extract event type from payload (default: `"type"`) |

## Registering Handlers

Register handlers for specific providers and event types:

```ruby
# Handle a specific event
InboundWebhooks.register_handler(
  provider: "stripe",
  event_type: "payment_intent.succeeded"
) do |webhook|
  PaymentIntent.find_by!(stripe_id: webhook.payload["data"]["object"]["id"]).mark_succeeded!
end

# Handle all events from a provider (wildcard)
InboundWebhooks.register_handler(
  provider: "github",
  event_type: "*"
) do |webhook|
  GithubEventProcessor.new(webhook.payload).process
end

# Custom retry configuration
InboundWebhooks.register_handler(
  provider: "stripe",
  event_type: "invoice.payment_failed",
  retry_enabled: true,
  max_retries: 5,
  retry_delay: 60  # fixed 60s delay
) do |webhook|
  InvoiceFailureHandler.call(webhook.payload)
end

# Disable retries
InboundWebhooks.register_handler(
  provider: "acme",
  event_type: "notification",
  retry_enabled: false
) do |webhook|
  Notification.create!(data: webhook.payload)
end
```

### Handler Options

| Option | Default | Description |
|---|---|---|
| `provider` | required | Provider name (must match route and config) |
| `event_type` | `"*"` | Event type to match (`"*"` for wildcard) |
| `retry_enabled` | `true` | Whether to retry on failure |
| `max_retries` | `3` | Maximum retry attempts |
| `retry_delay` | `:exponential` | `:exponential` (5s, 10s, 20s, 40s...) or integer seconds |

## Webhook Object

Handlers receive an `InboundWebhooks::Webhook` record:

```ruby
webhook.provider          # => "stripe"
webhook.event_type        # => "payment_intent.succeeded"
webhook.payload           # => Hash (parsed JSON)
webhook.headers           # => Hash (selected request headers)
webhook.provider_event_id # => "evt_1234567890"
webhook.ip_address        # => "1.2.3.4"
webhook.status            # => "processing"
webhook.retry_count       # => 0
webhook.created_at        # => Time
```

## How It Works

1. Webhook arrives at `POST /webhooks/:provider`
2. Engine authenticates (signature and/or API key)
3. Payload is parsed and stored in `inbound_webhooks_webhooks` table
4. Duplicate check via `provider_event_id` (skips if already exists)
5. `ProcessWebhookJob` is enqueued
6. Job finds matching handlers and executes them
7. On success: status → `processed`
8. On failure: retries (if enabled) or status → `failed`

## Testing

```bash
bundle exec rspec
```

## License

MIT License.
