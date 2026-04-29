# frozen_string_literal: true

class DoraEvent < ActiveRecord::Base
  TYPES = %w[deploy incident recovery].freeze

  belongs_to :issue,      optional: true
  belongs_to :repository, class_name: 'Repository::Github', optional: true

  validates :event_type,  inclusion: { in: TYPES }
  validates :occurred_at, presence: true

  scope :deploys,     -> { where(event_type: 'deploy') }
  scope :incidents,   -> { where(event_type: 'incident') }
  scope :recoveries,  -> { where(event_type: 'recovery') }
  scope :in_range,    ->(from, to) { where(occurred_at: from..to) }

  # Record an event idempotently using delivery_id.
  # If delivery_id is nil, always inserts.
  def self.record(event_type:, delivery_id: nil, **attrs)
    if delivery_id.present?
      find_or_create_by(delivery_id: delivery_id) do |e|
        e.event_type  = event_type
        e.occurred_at = attrs[:occurred_at] || Time.current
        attrs.each { |k, v| e.public_send(:"#{k}=", v) }
      end
    else
      create!(event_type: event_type, occurred_at: Time.current, **attrs)
    end
  rescue ActiveRecord::RecordNotUnique
    find_by(delivery_id: delivery_id)
  end

  # DORA: deployment frequency (deploys per week) for date range.
  def self.deployment_frequency(from, to)
    count = deploys.in_range(from, to).count
    weeks = [(to - from) / 1.week, 1].max
    (count.to_f / weeks).round(2)
  end

  # DORA: MTTR in minutes — mean time from incident to recovery for matched pairs.
  # Pairs are matched by issue_id + ref within the range.
  def self.mttr_minutes(from, to)
    recovery_events = recoveries.in_range(from, to).where.not(issue_id: nil).to_a
    return nil if recovery_events.empty?

    durations = recovery_events.filter_map do |r|
      incident = incidents
                   .where(issue_id: r.issue_id, ref: r.ref)
                   .where(occurred_at: ..r.occurred_at)
                   .order(occurred_at: :desc)
                   .first
      next unless incident

      (r.occurred_at - incident.occurred_at) / 60.0
    end

    return nil if durations.empty?

    (durations.sum / durations.size).round(1)
  end

  # DORA: change failure rate — fraction of deploys that were hotfixes (i.e., had a prior incident).
  def self.change_failure_rate(from, to)
    deploy_events = deploys.in_range(from, to).where.not(issue_id: nil).to_a
    return nil if deploy_events.empty?

    failures = deploy_events.count do |d|
      incidents.where(issue_id: d.issue_id, ref: d.ref).exists?
    end

    (failures.to_f / deploy_events.size * 100).round(1)
  end

  # Quarter boundaries for reporting.
  def self.current_quarter_range
    today = Date.today
    quarter_start = Date.new(today.year, ((today.month - 1) / 3) * 3 + 1, 1)
    quarter_end   = (quarter_start >> 3) - 1
    quarter_start.beginning_of_day..quarter_end.end_of_day
  end
end
