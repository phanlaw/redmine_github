# frozen_string_literal: true

class WebhookDelivery < ApplicationRecord
  belongs_to :repository, polymorphic: true, optional: true

  scope :stale, -> { where('created_at < ?', 30.days.ago) }

  def self.record_delivery(delivery_id, repository, event_type)
    find_or_create_by(delivery_id: delivery_id) do |wd|
      wd.repository = repository
      wd.event_type = event_type
      wd.created_at = Time.current
    end
  end

  def self.already_processed?(delivery_id)
    exists?(delivery_id: delivery_id)
  end

  def self.cleanup_stale
    stale.delete_all
  end
end
