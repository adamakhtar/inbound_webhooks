module InboundWebhooks
  module Admin
    class ApplicationController < InboundWebhooks.configuration.admin_base_controller.constantize
      include Pagy::Backend

      layout "inbound_webhooks/admin"
    end
  end
end
