class ProjectThreshold < ApplicationRecord
  belongs_to :project

  validates :project_id, presence: true, uniqueness: true
  validates :completion_ok, :completion_warning, :bug_rate_ok, :bug_rate_warning,
            :delay_rate_ok, :delay_rate_warning, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :cycle_time_baseline_days, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :completion_ok_greater_than_warning
  validate :bug_rate_ok_less_than_warning
  validate :delay_rate_ok_less_than_warning

  def self.for_project(project)
    find_or_create_by(project_id: project.id)
  end

  def evaluate_completion(rate)
    case rate
    when completion_ok..Float::INFINITY
      :ok
    when completion_warning...completion_ok
      :warning
    else
      :critical
    end
  end

  def evaluate_bug_rate(rate)
    case rate
    when 0..bug_rate_ok
      :ok
    when bug_rate_ok...bug_rate_warning
      :warning
    else
      :critical
    end
  end

  def evaluate_delay_rate(rate)
    case rate
    when 0..delay_rate_ok
      :ok
    when delay_rate_ok...delay_rate_warning
      :warning
    else
      :critical
    end
  end

  def evaluate_cycle_time(days)
    return :ok if cycle_time_baseline_days.blank?

    threshold = cycle_time_baseline_days * 1.1
    case days
    when 0..cycle_time_baseline_days
      :ok
    when cycle_time_baseline_days...threshold
      :warning
    else
      :critical
    end
  end

  private

  def completion_ok_greater_than_warning
    return if completion_ok.blank? || completion_warning.blank?

    if completion_ok < completion_warning
      errors.add(:completion_ok, "must be greater than or equal to completion warning")
    end
  end

  def bug_rate_ok_less_than_warning
    return if bug_rate_ok.blank? || bug_rate_warning.blank?

    if bug_rate_ok > bug_rate_warning
      errors.add(:bug_rate_ok, "must be less than or equal to bug rate warning")
    end
  end

  def delay_rate_ok_less_than_warning
    return if delay_rate_ok.blank? || delay_rate_warning.blank?

    if delay_rate_ok > delay_rate_warning
      errors.add(:delay_rate_ok, "must be less than or equal to delay rate warning")
    end
  end
end
