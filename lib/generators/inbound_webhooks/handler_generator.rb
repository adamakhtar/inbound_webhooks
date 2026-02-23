module InboundWebhooks
  module Generators
    class HandlerGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :provider, type: :string, desc: "Provider name (e.g. stripe, github)"
      argument :handler_name, type: :string, desc: "Handler name (e.g. charge_succeeded)"

      def create_handler_file
        template "handler.rb.tt", File.join("app/inbound_webhooks", provider.underscore, "#{handler_name.underscore}_handler.rb")
      end

      private

      def handler_class_name
        "#{provider.camelize}::#{handler_name.camelize}Handler"
      end
    end
  end
end
