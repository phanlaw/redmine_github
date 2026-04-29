# frozen_string_literal: true

module RedmineGithub
  # Computes QA gate readiness for a Redmine Version (sprint/release).
  class QaGateStats
    EXECUTION_RATE_THRESHOLD = 95.0  # %

    def initialize(version)
      @version  = version
    end

    def call
      issues    = @version.fixed_issues.includes(:status, :tracker, :priority, :issue_test_result).to_a
      total     = issues.size

      tested    = issues.select(&:issue_test_result)
      passed    = tested.select { |i| i.issue_test_result.result == 'pass' }
      failed    = tested.select { |i| i.issue_test_result.result == 'fail' }
      blocked   = tested.select { |i| i.issue_test_result.result == 'blocked' }

      blockers  = issues.select { |i| i.priority.name.in?(%w[Immediate High]) && !i.status.is_closed? }

      signoff   = QaSignoff.for_version(@version)

      exec_rate = total.zero? ? 0.0 : (tested.size.to_f / total * 100).round(1)

      {
        total:              total,
        tested:             tested.size,
        passed:             passed.size,
        failed:             failed.size,
        blocked_count:      blocked.size,
        open_blockers:      blockers.size,
        execution_rate:     exec_rate,
        signoff_status:     signoff&.status,
        signoff_by:         signoff&.user&.login,
        execution_rate_ok:  exec_rate >= EXECUTION_RATE_THRESHOLD,
        blockers_ok:        blockers.empty?,
        signoff_ok:         signoff&.approved?,
        release_ready:      QaSignoff.release_ready?(@version) && blockers.empty? && exec_rate >= EXECUTION_RATE_THRESHOLD
      }
    end
  end
end
