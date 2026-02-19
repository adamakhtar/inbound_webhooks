module InboundWebhooks
  module Admin
    module WebhooksHelper
      include Pagy::Frontend

      def status_badge(status)
        content_tag(:span, status, class: "iw-badge iw-badge-#{status}")
      end

      def truncated_error(message, length: 120)
        return "" if message.blank?

        content_tag(:span, truncate(message, length: length), class: "iw-error-msg", title: message)
      end

      def preset_link(field, preset_value, label)
        current_preset = params[:"#{field}_preset"]
        is_active = current_preset == preset_value

        merged = request.query_parameters.merge("#{field}_preset" => preset_value, "#{field}_from" => nil, "#{field}_to" => nil)

        if is_active
          content_tag(:span, label, class: "active")
        else
          link_to(label, url_for(merged), class: "")
        end
      end

      def filter_active?
        %i[provider statuses created_at_preset created_at_from created_at_to
           processed_at_preset processed_at_from processed_at_to].any? { |k| params[k].present? }
      end

      def registered_provider_names
        InboundWebhooks.configuration.providers.keys.map(&:to_s).sort
      end
    end
  end
end
