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

      def syntax_highlighted_json(data)
        json = data.is_a?(String) ? data : JSON.pretty_generate(data)
        escaped = ERB::Util.html_escape(json)

        highlighted = escaped.gsub(
          /("(?:[^"\\]|\\.)*")\s*(:)|("(?:[^"\\]|\\.)*")|(true|false|null)|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/
        ) do
          if $1
            %(<span class="iw-json-key">#{$1}</span>#{$2})
          elsif $3
            %(<span class="iw-json-string">#{$3}</span>)
          elsif $4
            %(<span class="iw-json-bool">#{$4}</span>)
          elsif $5
            %(<span class="iw-json-number">#{$5}</span>)
          end
        end

        %(<pre class="iw-json"><code>#{highlighted}</code></pre>).html_safe
      end
    end
  end
end
