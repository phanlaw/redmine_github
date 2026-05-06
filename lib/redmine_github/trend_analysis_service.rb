# frozen_string_literal: true

module RedmineGithub
  # Service to analyze sprint trends over time.
  # Compares metrics (completion, cycle time, bug rate) across last N sprints.
  class TrendAnalysisService
    def initialize(project, sprint_count = 5)
      @project = project
      @sprint_count = sprint_count
    end

    def call
      {
        sprints: sprint_trends,
        completion_trend: completion_trend,
        cycle_time_trend: cycle_time_trend,
        bug_rate_trend: bug_rate_trend,
        avg_completion: average_metric(:completion_rate),
        avg_cycle_time: average_metric(:avg_cycle_time),
        avg_bug_rate: average_metric(:bug_rate)
      }
    end

    def sprint_trends
      recent_sprints.map do |sprint|
        stats = RedmineGithub::SprintPmStats.new(sprint).call
        {
          id: sprint.id,
          name: sprint.name,
          effective_date: sprint.effective_date,
          completion_rate: stats[:completion_rate] || 0,
          cycle_time: stats[:avg_cycle_time] || 0,
          bug_rate: stats[:bug_rate] || 0,
          closed_issues: stats[:closed_count] || 0,
          total_issues: stats[:total_count] || 0,
          bug_count: stats[:bug_count] || 0
        }
      end
    end

    def completion_trend
      sprint_trends.map { |s| s[:completion_rate] }
    end

    def cycle_time_trend
      sprint_trends.map { |s| s[:cycle_time] }
    end

    def bug_rate_trend
      sprint_trends.map { |s| s[:bug_rate] }
    end

    def average_metric(key)
      trends = sprint_trends
      return 0 if trends.empty?

      sum = trends.sum { |s| s[key].to_f }
      (sum / trends.count).round(2)
    end

    def trend_direction(metric)
      trends = case metric
               when :completion
                 completion_trend
               when :cycle_time
                 cycle_time_trend
               when :bug_rate
                 bug_rate_trend
               else
                 []
               end

      return :stable if trends.length < 2

      first = trends.first
      last = trends.last
      change = last - first

      if change > 2
        :up
      elsif change < -2
        :down
      else
        :stable
      end
    end

    def trend_icon(direction)
      case direction
      when :up
        '↑'
      when :down
        '↓'
      else
        '→'
      end
    end

    private

    def recent_sprints
      @recent_sprints ||= @project.versions
                                   .where('effective_date <= ?', Date.today)
                                   .order(effective_date: :desc)
                                   .limit(@sprint_count)
                                   .reverse
    end
  end
end
