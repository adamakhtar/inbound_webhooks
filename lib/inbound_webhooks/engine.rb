module InboundWebhooks
  class Engine < ::Rails::Engine
    isolate_namespace InboundWebhooks

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
