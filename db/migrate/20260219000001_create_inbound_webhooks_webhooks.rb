class CreateInboundWebhooksWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :inbound_webhooks_webhooks do |t|
      t.string :provider, null: false
      t.string :event_type, null: false
      t.string :provider_event_id
      t.json :payload, null: false
      t.json :headers
      t.string :ip_address
      t.string :status, null: false, default: "pending"
      t.integer :retry_count, default: 0
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :inbound_webhooks_webhooks, :provider
    add_index :inbound_webhooks_webhooks, :event_type
    add_index :inbound_webhooks_webhooks, [:provider, :provider_event_id], unique: true, where: "provider_event_id IS NOT NULL"
    add_index :inbound_webhooks_webhooks, :status
    add_index :inbound_webhooks_webhooks, [:provider, :event_type]
    add_index :inbound_webhooks_webhooks, [:status, :created_at]
  end
end
