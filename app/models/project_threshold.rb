class ProjectThreshold < ApplicationRecord
  belongs_to :project

  validates :project_id, presence: true, uniqueness: true
  validates :completion_ok, :completion_warning, :bug_rate_ok, :bug_rate_warning,
            :delay_rate_ok, :delay_rate_warning, presence: true

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
end
