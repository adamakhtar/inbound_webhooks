module InboundWebhooks
  class ProcessWebhookJob < ApplicationJob
    queue_as :webhooks

    def perform(webhook_id)
      webhook = Webhook.claim_for_processing!(webhook_id)
      return unless webhook

      handler = InboundWebhooks.handler_for(webhook.provider, webhook.event_type)

      unless handler
        webhook.mark_unhandled!
        return
      end

      handler.call(webhook)
      webhook.mark_processed!
    rescue => e
      handle_failure(webhook, handler, e)
    end

    private

    def handle_failure(webhook, handler, error)
      return unless webhook

      if handler&.retry_enabled && webhook.retry_count < handler.max_retries
        webhook.mark_retrying!(error)
        delay = handler.retry_delay_for(webhook.retry_count)
        self.class.set(wait: delay.seconds).perform_later(webhook.id)
      else
        webhook.mark_failed!(error)
      end
    end
  end
end
