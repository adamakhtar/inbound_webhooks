module InboundWebhooks
  class Webhook < ApplicationRecord
    STATUSES = %w[pending processing processed failed].freeze
    CLAIMABLE_STATUSES = %w[pending failed].freeze

    validates :provider, presence: true
    validates :event_type, presence: true
    validates :payload, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :by_provider, ->(provider) { where(provider: provider) }
    scope :by_event_type, ->(event_type) { where(event_type: event_type) }
    scope :pending, -> { where(status: "pending") }
    scope :processing, -> { where(status: "processing") }
    scope :processed, -> { where(status: "processed") }
    scope :failed, -> { where(status: "failed") }
    scope :retryable, -> { failed.where("retry_count < ?", 3) }

    def self.claim_for_processing!(id)
      claimed = atomically_transition_to(id, "processing", from: CLAIMABLE_STATUSES)
      find(id) if claimed
    end

    def mark_processed!
      update!(status: "processed", processed_at: Time.current)
    end

    def mark_failed!(error)
      update!(
        status: "failed",
        error_message: error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
      )
    end

    def increment_retry!
      increment!(:retry_count)
    end

    def pending?
      status == "pending"
    end

    def processed?
      status == "processed"
    end

    def failed?
      status == "failed"
    end

    private

    def self.atomically_transition_to(id, new_status, from:)
      rows_updated = where(id: id, status: from).update_all(status: new_status)
      rows_updated > 0
    end
  end
end
