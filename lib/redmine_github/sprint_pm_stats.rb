# frozen_string_literal: true

module RedmineGithub
  # Computes PM success metrics for a Redmine Version (sprint).
  class SprintPmStats
    COMPLETION_THRESHOLD  = 85.0   # %
    BUG_RATE_THRESHOLD    = 3.0    # %
    DELAY_RATE_THRESHOLD  = 10.0   # %

    def initialize(version)
      @version = version
    end

    def call
      issues  = @version.fixed_issues.includes(:status, :tracker, :priority).to_a
      total   = issues.size
      return empty_stats if total.zero?

      closed   = issues.select { |i| i.status.is_closed? }
      bugs     = issues.select { |i| i.tracker.name == 'Bug' }
      delayed  = closed.select { |i| i.due_date && i.closed_on && i.closed_on.to_date > i.due_date }
      cycles   = closed.select { |i| i.start_date && i.closed_on }

      completion_rate = (closed.size.to_f / total * 100).round(1)
      bug_rate        = (bugs.size.to_f / total * 100).round(1)
      delay_rate      = closed.empty? ? 0.0 : (delayed.size.to_f / closed.size * 100).round(1)
      avg_cycle_days  = cycles.empty? ? nil : (cycles.sum { |i| (i.closed_on.to_date - i.start_date).to_i } / cycles.size.to_f).round(1)

      {
        total:               total,
        closed:              closed.size,
        bugs:                bugs.size,
        delayed:             delayed.size,
        completion_rate:     completion_rate,
        bug_rate:            bug_rate,
        delay_rate:          delay_rate,
        avg_cycle_days:      avg_cycle_days,
        completion_ok:       completion_rate >= COMPLETION_THRESHOLD,
        bug_rate_ok:         bug_rate <= BUG_RATE_THRESHOLD,
        delay_rate_ok:       delay_rate <= DELAY_RATE_THRESHOLD
      }
    end

    private

    def empty_stats
      {
        total: 0, closed: 0, bugs: 0, delayed: 0,
        completion_rate: 0.0, bug_rate: 0.0, delay_rate: 0.0, avg_cycle_days: nil,
        completion_ok: false, bug_rate_ok: true, delay_rate_ok: true
      }
    end
  end
end
