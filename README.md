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

Configure providers and handlers in an initializer. `config.provider` returns an `InboundWebhooks::Provider` instance you use to register handlers.

```ruby
# config/initializers/inbound_webhooks.rb

InboundWebhooks.configure do |config|
  # Stripe — HMAC signature with timestamped format
  stripe = config.provider(:stripe,
    signature_header: "HTTP_STRIPE_SIGNATURE",
    signature_algorithm: "sha256",
    signature_format: :timestamped,
    secret: ENV["STRIPE_WEBHOOK_SECRET"],
    event_type_key: "type"
  )

  stripe.on "invoice.payment_failed", handler: "InvoiceFailureHandler"
  stripe.on "charge.succeeded", "charge.failed"

  # GitHub — HMAC signature with simple format
  github = config.provider(:github,
    signature_header: "HTTP_X_HUB_SIGNATURE_256",
    signature_algorithm: "sha256",
    secret: ENV["GITHUB_WEBHOOK_SECRET"],
    event_type_key: "action"
  )

  github.on "*", handler: "Github::CatchAllHandler"

  # Simple provider — API key only
  acme = config.provider(:acme,
    api_key_header: "HTTP_X_API_KEY",
    api_key: ENV["ACME_WEBHOOK_API_KEY"]
  )

  acme.on "notification", handler: "AcmeNotificationHandler"
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
| `retry_enabled` | `true` | Default retry setting for handlers on this provider |
| `max_retries` | `3` | Default max retries for handlers on this provider |
| `retry_delay` | `:exponential` | Default retry delay for handlers on this provider |

## Registering Handlers

Handlers are registered on providers using the `on` method. Each handler is a class with a `#call(webhook)` instance method.

```ruby
InboundWebhooks.configure do |config|
  stripe = config.provider(:stripe,
    signature_header: "HTTP_STRIPE_SIGNATURE",
    signature_format: :timestamped,
    secret: ENV["STRIPE_WEBHOOK_SECRET"],
    event_type_key: "type"
  )

  # Explicit handler mapping
  stripe.on "invoice.payment_failed", handler: "InvoiceFailureHandler"
  stripe.on "invoice.payment_ok",     handler: "InvoiceOKHandler"

  # Convention-based shorthand — derives class name from provider + event type
  # "charge.succeeded" on :stripe => Stripe::ChargeSucceededHandler
  stripe.on "charge.succeeded", "charge.failed", "customer.created"

  # Wildcard (requires explicit handler)
  stripe.on "*", handler: "Stripe::CatchAllHandler"
end
```

### Handler Classes

A handler is any class that implements `#call(webhook)`:

```ruby
class InvoiceFailureHandler
  def call(webhook)
    invoice = Invoice.find_by!(stripe_id: webhook.payload["data"]["object"]["id"])
    invoice.mark_failed!
  end
end
```

### Convention-Based Naming

When you omit the `handler:` keyword, the handler class is derived from the provider name and event type:

| Provider | Event Type | Handler Class |
|---|---|---|
| `:stripe` | `"charge.succeeded"` | `Stripe::ChargeSucceededHandler` |
| `:stripe` | `"invoice.payment_failed"` | `Stripe::InvoicePaymentFailedHandler` |
| `:github` | `"push"` | `Github::PushHandler` |

### Retry Configuration

Retry settings are resolved in order: handler class → provider defaults → global defaults.

Set defaults on the provider:

```ruby
config.provider(:stripe,
  secret: ENV["STRIPE_WEBHOOK_SECRET"],
  retry_enabled: true,
  max_retries: 5,
  retry_delay: :exponential
)
```

Override per handler class:

```ruby
class InvoiceFailureHandler
  def self.retry_enabled = true
  def self.max_retries = 10
  def self.retry_delay = 60  # fixed 60s delay

  def call(webhook)
    # ...
  end
end
```

| Option | Default | Description |
|---|---|---|
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

## Generators

### Install

Generates the initializer at `config/initializers/inbound_webhooks.rb` with commented-out examples for providers, handlers, and admin dashboard config:

```bash
bin/rails generate inbound_webhooks:install
```

### Handler

Scaffolds a new handler class under `app/inbound_webhooks/`:

```bash
bin/rails generate inbound_webhooks:handler PROVIDER HANDLER_NAME
```

For example:

```bash
bin/rails generate inbound_webhooks:handler stripe charge_succeeded
```

This creates `app/inbound_webhooks/stripe/charge_succeeded_handler.rb`:

```ruby
class Stripe::ChargeSucceededHandler
  def call(webhook)
  end
end
```

## Testing

```bash
bundle exec rspec
```

## License

MIT License.
