module InboundWebhooks
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "initializer.rb", "config/initializers/inbound_webhooks.rb"
      end

      def copy_migrations
        rails_command "inbound_webhooks:install:migrations"
      end
    end
  end
end
