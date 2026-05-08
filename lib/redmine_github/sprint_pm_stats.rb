# frozen_string_literal: true

module RedmineGithub
  # Computes PM success metrics for a Redmine Version (sprint).
  class SprintPmStats
    COMPLETION_THRESHOLD  = 85.0   # %
    BUG_RATE_THRESHOLD    = 3.0    # %
    DELAY_RATE_THRESHOLD  = 10.0   # %
    HIGH_LOAD_THRESHOLD   = 5      # open tasks per member

    def initialize(version)
      @version = version
    end

    def call
      issues  = @version.fixed_issues.includes(:status, :tracker, :priority, :assigned_to).to_a
      total   = issues.size
      return empty_stats if total.zero?

      closed   = issues.select { |i| i.status.is_closed? }
      bugs     = issues.select { |i| i.tracker.name == 'Bug' }
      delayed  = closed.select { |i| i.due_date && i.closed_on && i.closed_on.to_date > i.due_date }
      cycles   = closed.select { |i| i.start_date && i.closed_on }

      # Blockers: High/Immediate priority + open status
      blocker_priorities = IssuePriority.where(name: %w[High Immediate]).pluck(:id)
      blockers = issues.select { |i| !i.status.is_closed? && blocker_priorities.include?(i.priority_id) }

      # DoD: tasks without a "clear" status are those still in the default "New" state
      new_status_ids = IssueStatus.where(name: 'New').pluck(:id)
      not_started    = issues.select { |i| new_status_ids.include?(i.status_id) }

      # DoD: blockers that have had no update within the last 48 hours
      stale_threshold = 48.hours.ago
      stale_blockers  = blockers.select do |i|
        last_update = i.updated_on || i.created_on
        last_update && last_update < stale_threshold
      end

      # Needs Attention: non-blocker open issues also stale
      stale_non_blockers = issues.select do |i|
        !i.status.is_closed? &&
          !blocker_priorities.include?(i.priority_id) &&
          ((i.updated_on || i.created_on)&.<(stale_threshold))
      end

      completion_rate = (closed.size.to_f / total * 100).round(1)
      bug_rate        = (bugs.size.to_f / total * 100).round(1)
      delay_rate      = closed.empty? ? 0.0 : (delayed.size.to_f / closed.size * 100).round(1)
      avg_cycle_days  = cycles.empty? ? nil : [(cycles.sum { |i| (i.closed_on.to_date - i.start_date).to_i } / cycles.size.to_f).round(1), 0].max

      blockers_data = blockers.map do |b|
        {
          id: b.id, subject: b.subject,
          tracker: b.tracker.name, priority: b.priority.name,
          status: b.status.name, assignee: b.assigned_to&.name || 'Unassigned',
          created_on: b.created_on, updated_on: b.updated_on
        }
      end

      team_load = issues
        .group_by { |i| i.assigned_to&.name || 'Unassigned' }
        .map do |name, member_issues|
          open_count    = member_issues.count { |i| !i.status.is_closed? }
          blocked_count = member_issues.count { |i| !i.status.is_closed? && blocker_priorities.include?(i.priority_id) }
          notes = []
          notes << 'blocked'   if blocked_count.positive?
          notes << 'high load' if open_count >= HIGH_LOAD_THRESHOLD
          {
            name:    name,
            total:   member_issues.size,
            open:    open_count,
            closed:  member_issues.count { |i| i.status.is_closed? },
            blocked: blocked_count,
            notes:   notes.join(', ')
          }
        end
        .sort_by { |m| [-m[:blocked], -m[:open]] }

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
        delay_rate_ok:       delay_rate <= DELAY_RATE_THRESHOLD,
        blockers:            blockers_data,
        not_started:         not_started.map { |i| { id: i.id, subject: i.subject } },
        stale_blockers:      stale_blockers.map { |i| { id: i.id, subject: i.subject, updated_on: i.updated_on || i.created_on } },
        stale_issues:        stale_non_blockers.map { |i| { id: i.id, subject: i.subject, updated_on: i.updated_on || i.created_on } },
        team_load:           team_load
      }
    end

    def health_summary
      project = @version.project
      threshold = ProjectThreshold.for_project(project)
      stats = call

      {
        completion_rate:     { value: stats[:completion_rate], status: threshold.evaluate_completion(stats[:completion_rate]) },
        bug_rate:            { value: stats[:bug_rate], status: threshold.evaluate_bug_rate(stats[:bug_rate]) },
        delay_rate:          { value: stats[:delay_rate], status: threshold.evaluate_delay_rate(stats[:delay_rate]) },
        cycle_time:          { value: stats[:avg_cycle_days], status: threshold.evaluate_cycle_time(stats[:avg_cycle_days] || 0) },
        overall_status:      compute_overall_status(threshold, stats)
      }
    end

    private

    def empty_stats
      {
        total: 0, closed: 0, bugs: 0, delayed: 0,
        completion_rate: 0.0, bug_rate: 0.0, delay_rate: 0.0, avg_cycle_days: nil,
        completion_ok: false, bug_rate_ok: true, delay_rate_ok: true,
        blockers: [], not_started: [], stale_blockers: [], stale_issues: [], team_load: []
      }
    end

    def compute_overall_status(threshold, stats)
      statuses = [
        threshold.evaluate_completion(stats[:completion_rate]),
        threshold.evaluate_bug_rate(stats[:bug_rate]),
        threshold.evaluate_delay_rate(stats[:delay_rate]),
        threshold.evaluate_cycle_time(stats[:avg_cycle_days] || 0)
      ]

      return :critical if statuses.include?(:critical)
      return :warning if statuses.include?(:warning)

      :ok
    end
  end
end
