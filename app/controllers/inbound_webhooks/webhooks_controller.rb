module InboundWebhooks
  class WebhooksController < ApplicationController
    before_action :set_provider
    before_action :read_raw_body
    before_action :authenticate!

    def create
      webhook = Webhook.new(
        provider: @provider,
        event_type: extract_event_type,
        provider_event_id: extract_provider_event_id,
        payload: parsed_payload,
        headers: safe_headers,
        ip_address: request.remote_ip,
        status: "pending"
      )

      if webhook.provider_event_id.present? && Webhook.exists?(provider: @provider, provider_event_id: webhook.provider_event_id)
        head :ok
        return
      end

      begin
        if webhook.save
          ProcessWebhookJob.perform_later(webhook.id)
          head :ok
        else
          head :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        head :ok
      end
    end

    private

    def set_provider
      @provider = params[:provider]
      head :not_found unless provider_config
    end

    def read_raw_body
      @raw_body = request.body.read
      request.body.rewind
    end

    def authenticate!
      verify_signature!
      validate_api_key!
    rescue SignatureVerifier::VerificationFailed, ApiKeyValidator::ValidationFailed => e
      render json: {error: e.message}, status: :unauthorized
    end

    def verify_signature!
      SignatureVerifier.new(provider_config).verify!(@raw_body, request.headers)
    end

    def validate_api_key!
      ApiKeyValidator.new(provider_config).validate!(request)
    end

    def provider_config
      @provider_config ||= InboundWebhooks.configuration.provider_config(@provider)
    end

    def parsed_payload
      @parsed_payload ||= JSON.parse(@raw_body)
    rescue JSON::ParserError
      {}
    end

    def extract_event_type
      key = provider_config[:event_type_key] || "type"
      parsed_payload.dig(*Array(key)) || "unknown"
    end

    def extract_provider_event_id
      parsed_payload["id"]
    end

    def safe_headers
      headers_to_store = %w[
        HTTP_CONTENT_TYPE
        HTTP_USER_AGENT
        HTTP_X_REQUEST_ID
      ]

      sig_header = provider_config[:signature_header]
      headers_to_store << sig_header if sig_header

      headers_to_store.each_with_object({}) do |header, hash|
        value = request.headers[header]
        hash[header] = value if value.present?
      end
    end
  end
end
