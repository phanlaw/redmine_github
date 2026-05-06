class MetricSnapshot < ApplicationRecord
  belongs_to :version

  validates :version_id, presence: true
  validates :data, presence: true
  validates :calculated_at, presence: true

  scope :for_version, ->(version) { where(version_id: version.id) }
  scope :latest, -> { order(calculated_at: :desc).limit(1) }
  scope :since, ->(time) { where('calculated_at >= ?', time) }

  def self.calculate_for(version)
    sprint_stats = RedmineGithub::SprintPmStats.new(version).call
    qa_stats = RedmineGithub::QaGateStats.new(version).call

    data = {
      completion_rate: sprint_stats[:completion_rate],
      completion_ok: sprint_stats[:completion_ok],
      bug_rate: sprint_stats[:bug_rate],
      bug_rate_ok: sprint_stats[:bug_rate_ok],
      delay_rate: sprint_stats[:delay_rate],
      delay_rate_ok: sprint_stats[:delay_rate_ok],
      avg_cycle_time: sprint_stats[:avg_cycle_days],
      test_execution_rate: qa_stats[:test_execution_rate],
      test_execution_ok: qa_stats[:test_execution_ok],
      open_blockers: qa_stats[:open_blockers],
      blockers_ok: qa_stats[:blockers_ok],
      qa_approved: qa_stats[:qa_approved],
      release_ready: qa_stats[:release_ready]
    }

    create(
      version_id: version.id,
      data: data,
      calculated_at: Time.current
    )
  end

  def completion_rate
    data['completion_rate']
  end

  def bug_rate
    data['bug_rate']
  end

  def delay_rate
    data['delay_rate']
  end

  def avg_cycle_time
    data['avg_cycle_time']
  end

  def test_execution_rate
    data['test_execution_rate']
  end

  def open_blockers
    data['open_blockers']
  end

  def release_ready?
    data['release_ready']
  end
end
