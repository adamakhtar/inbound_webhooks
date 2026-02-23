module InboundWebhooks
  module Admin
    class ApplicationController < InboundWebhooks.configuration.admin_base_controller.constantize
      include Pagy::Backend

      before_action :authenticate_inbound_webhooks_user!
      before_action :authorize_inbound_webhooks_user!

      layout "inbound_webhooks/admin"

      helper_method :inbound_webhooks_current_user

      private

      def authenticate_inbound_webhooks_user!
        return unless InboundWebhooks.configuration.admin_authentication_required

        method_name = InboundWebhooks.configuration.admin_authentication_method

        unless respond_to?(method_name, true)
          raise NoMethodError,
            "InboundWebhooks: admin_authentication_method #{method_name.inspect} is not available. " \
            "Make sure admin_base_controller (#{InboundWebhooks.configuration.admin_base_controller}) defines it."
        end

        send(method_name)
      end

      def authorize_inbound_webhooks_user!
        return unless InboundWebhooks.configuration.admin_authorization_required

        method_name = InboundWebhooks.configuration.admin_authorization_method

        unless respond_to?(method_name, true)
          raise NoMethodError,
            "InboundWebhooks: admin_authorization_method #{method_name.inspect} is not available. " \
            "Make sure admin_base_controller (#{InboundWebhooks.configuration.admin_base_controller}) defines it."
        end

        send(method_name)
      end

      def inbound_webhooks_current_user
        method_name = InboundWebhooks.configuration.admin_current_user_method
        return unless method_name

        unless respond_to?(method_name, true)
          raise NoMethodError,
            "InboundWebhooks: admin_current_user_method #{method_name.inspect} is not available. " \
            "Make sure admin_base_controller (#{InboundWebhooks.configuration.admin_base_controller}) defines it."
        end

        send(method_name)
      end
    end
  end
end
