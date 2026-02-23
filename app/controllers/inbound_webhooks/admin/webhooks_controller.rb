module InboundWebhooks
  module Admin
    class WebhooksController < ApplicationController
      def show
        @webhook = Webhook.find(params[:id])
      end

      def index
        scope = Webhook.all
        scope = scope.by_provider(params[:provider]) if params[:provider].present?
        scope = scope.by_statuses(Array(params[:statuses])) if params[:statuses].present?
        scope = apply_date_filter(scope, :created_at)
        scope = apply_date_filter(scope, :processed_at)
        scope = apply_ordering(scope)
        @pagy, @webhooks = pagy(scope, limit: 25)
      end

      private

      DATE_PRESETS = {
        "2h"  => 2.hours,
        "12h" => 12.hours,
        "24h" => 24.hours,
        "3d"  => 3.days,
        "1w"  => 1.week
      }.freeze

      def apply_date_filter(scope, field)
        preset = params[:"#{field}_preset"]
        from   = params[:"#{field}_from"]
        to     = params[:"#{field}_to"]

        if preset.present? && DATE_PRESETS.key?(preset)
          scope.where(field => DATE_PRESETS[preset].ago..)
        elsif from.present? || to.present?
          parsed_from = from.present? ? Time.zone.parse(from) : nil
          parsed_to   = to.present? ? Time.zone.parse(to).end_of_day : nil
          scope.where(field => (parsed_from)..(parsed_to))
        else
          scope
        end
      end

      def apply_ordering(scope)
        case params[:order]
        when "recently_created"
          scope.order_by_recently_created
        else
          scope.order_by_recently_processed
        end
      end
    end
  end
end
