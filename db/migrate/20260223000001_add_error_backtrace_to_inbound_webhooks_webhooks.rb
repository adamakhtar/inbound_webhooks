class AddErrorBacktraceToInboundWebhooksWebhooks < ActiveRecord::Migration[7.0]
  def change
    add_column :inbound_webhooks_webhooks, :error_backtrace, :text
  end
end
