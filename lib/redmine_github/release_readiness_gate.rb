# frozen_string_literal: true

module RedmineGithub
  # Evaluates whether a sprint is ready for production release.
  # Combines health status, QA signoff, blockers, and test execution.
  class ReleaseReadinessGate
    EXECUTION_RATE_THRESHOLD = 95.0

    def initialize(version, health_summary:, qa_stats:, sprint_stats:)
      @version = version
      @health_summary = health_summary
      @qa_stats = qa_stats
      @sprint_stats = sprint_stats
    end

    def call
      {
        status: compute_status,
        signals: compute_signals,
        ready: compute_status == :ready,
        risky: compute_status == :risky,
        blocked: compute_status == :blocked,
        rules: release_rules
      }
    end

    private

    def compute_status
      # Blocked if critical issues
      return :blocked if @qa_stats[:blockers_ok].blank? || !@qa_stats[:blockers_ok]
      return :blocked if @qa_stats[:signoff_status] == 'rejected'

      # Ready if all good
      return :ready if all_signals_good?

      # Risky if health warning or execution rate low
      return :risky if health_warning? || execution_rate_warning?

      # Otherwise ready but with caution
      :ready
    end

    def compute_signals
      {
        health_status: {
          status: @health_summary[:overall_status],
          ok: @health_summary[:overall_status] == :ok,
          label: "Sprint Health"
        },
        qa_signoff: {
          status: @qa_stats[:signoff_status] || 'pending',
          ok: @qa_stats[:signoff_ok],
          label: "QA Sign-off"
        },
        blockers: {
          count: @qa_stats[:open_blockers] || 0,
          ok: (@qa_stats[:open_blockers] || 0).zero?,
          label: "Open Blockers"
        },
        execution_rate: {
          rate: @qa_stats[:execution_rate] || 0,
          ok: (@qa_stats[:execution_rate] || 0) >= EXECUTION_RATE_THRESHOLD,
          label: "Test Execution Rate"
        }
      }
    end

    def release_rules
      [
        {
          rule: "Sprint Health OK",
          description: "All metrics (completion, bug rate, delay rate, cycle time) must be in OK or Warning status",
          required: true
        },
        {
          rule: "No Open Blockers",
          description: "All High/Immediate priority issues must be resolved or in progress",
          required: true
        },
        {
          rule: "QA Sign-off Approved",
          description: "QA must explicitly approve the release",
          required: true
        },
        {
          rule: "Test Execution ≥ #{EXECUTION_RATE_THRESHOLD}%",
          description: "At least #{EXECUTION_RATE_THRESHOLD}% of issues must have test results",
          required: true
        }
      ]
    end

    def all_signals_good?
      signals = compute_signals
      signals[:health_status][:ok] &&
        signals[:qa_signoff][:ok] &&
        signals[:blockers][:ok] &&
        signals[:execution_rate][:ok]
    end

    def health_warning?
      @health_summary[:overall_status] == :warning
    end

    def execution_rate_warning?
      (@qa_stats[:execution_rate] || 0) < EXECUTION_RATE_THRESHOLD
    end
  end
end
