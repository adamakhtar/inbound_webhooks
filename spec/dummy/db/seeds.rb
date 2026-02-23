InboundWebhooks.configure do |config|
  config.provider(:stripe)
  config.provider(:github)
end

User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "password"
  user.admin = true
end

puts "Seeded admin user (admin@example.com / password)"

sample_backtrace = <<~TRACE.strip
  /app/services/stripe/charge_handler.rb:42:in `process_charge'
  /app/services/stripe/charge_handler.rb:18:in `call'
  /app/jobs/inbound_webhooks/process_webhook_job.rb:16:in `perform'
  /gems/activejob-8.1.0/lib/active_job/execution.rb:45:in `perform_now'
  /gems/activejob-8.1.0/lib/active_job/execution.rb:22:in `execute'
  /gems/activejob-8.1.0/lib/active_job/queue_adapters/async_adapter.rb:34:in `block in enqueue'
  /gems/concurrent-ruby-1.3.5/lib/concurrent-ruby/concurrent/executor/ruby_thread_pool_executor.rb:367:in `run_task'
  /gems/activesupport-8.1.0/lib/active_support/error_reporter.rb:72:in `handle'
  /gems/activerecord-8.1.0/lib/active_record/connection_adapters/abstract/connection_pool.rb:385:in `with_connection'
  /app/models/stripe/charge.rb:107:in `validate_charge_state!'
  /app/models/stripe/charge.rb:83:in `transition_to_failed'
  /app/services/payments/reconciliation_service.rb:29:in `reconcile'
  /app/services/payments/reconciliation_service.rb:12:in `call'
  /app/controllers/concerns/error_handling.rb:15:in `rescue_from_handler'
TRACE

samples = [
  {provider: "stripe", event_type: "payment_intent.succeeded", status: "processed", processed_at: 30.minutes.ago, payload: {"id" => "evt_1"}},
  {provider: "stripe", event_type: "charge.failed", status: "failed", error_message: "Stripe::InvalidRequestError: No such charge: ch_abc123", error_backtrace: sample_backtrace, retry_count: 3, payload: {"id" => "evt_2"}},
  {provider: "stripe", event_type: "invoice.paid", status: "retrying", error_message: "Net::ReadTimeout: execution expired", error_backtrace: sample_backtrace, retry_count: 1, processed_at: 5.minutes.ago, payload: {"id" => "evt_3"}},
  {provider: "github", event_type: "push", status: "processed", processed_at: 2.hours.ago, payload: {"id" => "gh_1"}},
  {provider: "github", event_type: "pull_request.opened", status: "pending", payload: {"id" => "gh_2"}},
  {provider: "stripe", event_type: "customer.subscription.deleted", status: "unhandled", payload: {"id" => "evt_4"}},
  {provider: "github", event_type: "issues.closed", status: "processed", processed_at: 1.day.ago, created_at: 2.days.ago, payload: {"id" => "gh_3"}},
  {provider: "stripe", event_type: "payment_intent.created", status: "processing", payload: {"id" => "evt_5"}}
]

samples.each do |attrs|
  InboundWebhooks::Webhook.create!(attrs)
end

puts "Seeded #{samples.size} webhooks"
