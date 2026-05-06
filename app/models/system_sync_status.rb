class SystemSyncStatus < ApplicationRecord
  SOURCES = %w[redmine github qa_signoff].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :last_sync_at, presence: true
  validates :source_updated_at, presence: true

  scope :by_source, ->(source) { where(source: source) }
  scope :recent, -> { order(last_sync_at: :desc) }

  def self.update_sync(source, source_updated_at = Time.current)
    raise "Invalid source: #{source}" unless SOURCES.include?(source)

    record = find_or_initialize_by(source: source)
    record.update(
      last_sync_at: Time.current,
      source_updated_at: source_updated_at
    )
    record
  end

  def stale?
    last_sync_at < 1.hour.ago
  end

  def freshness_label
    ago = Time.current - last_sync_at
    if ago < 5.minutes
      "Just now"
    elsif ago < 1.hour
      "#{(ago / 60).to_i}m ago"
    elsif ago < 1.day
      "#{(ago / 3600).to_i}h ago"
    else
      "#{(ago / 86400).to_i}d ago"
    end
  end
end
