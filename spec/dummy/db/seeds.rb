InboundWebhooks.configure do |config|
  config.provider(:stripe)
  config.provider(:github)
end

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "password"
  user.admin = true
end

puts "Seeded admin user (admin@example.com / password)"

samples = [
  { provider: "stripe", event_type: "payment_intent.succeeded", status: "processed", processed_at: 30.minutes.ago, payload: { "id" => "evt_1" } },
  { provider: "stripe", event_type: "charge.failed", status: "failed", error_message: "Stripe::InvalidRequestError: No such charge: ch_abc123", retry_count: 3, payload: { "id" => "evt_2" } },
  { provider: "stripe", event_type: "invoice.paid", status: "retrying", error_message: "Net::ReadTimeout: execution expired", retry_count: 1, processed_at: 5.minutes.ago, payload: { "id" => "evt_3" } },
  { provider: "github", event_type: "push", status: "processed", processed_at: 2.hours.ago, payload: { "id" => "gh_1" } },
  { provider: "github", event_type: "pull_request.opened", status: "pending", payload: { "id" => "gh_2" } },
  { provider: "stripe", event_type: "customer.subscription.deleted", status: "unhandled", payload: { "id" => "evt_4" } },
  { provider: "github", event_type: "issues.closed", status: "processed", processed_at: 1.day.ago, created_at: 2.days.ago, payload: { "id" => "gh_3" } },
  { provider: "stripe", event_type: "payment_intent.created", status: "processing", payload: { "id" => "evt_5" } }
]

samples.each do |attrs|
  InboundWebhooks::Webhook.create!(attrs)
end

puts "Seeded #{samples.size} webhooks"
