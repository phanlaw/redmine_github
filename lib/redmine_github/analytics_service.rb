# frozen_string_literal: true

module RedmineGithub
  # Service for aggregating and presenting dashboard usage analytics.
  class AnalyticsService
    def initialize(project, period = :week)
      @project = project
      @period = period
    end

    def call
      {
        page_views: page_views_count,
        drill_downs: drill_down_breakdown,
        approval_actions: approval_breakdown,
        active_users: active_users_count,
        top_users: top_users_data,
        usage_summary: usage_summary,
        period: @period
      }
    end

    private

    def page_views_count
      DashboardAnalytic.by_project(@project)
                       .by_event('page_view')
                       .send("this_#{@period}").count
    end

    def drill_down_breakdown
      DashboardAnalytic.by_project(@project).by_event('drill_down_click').send("this_#{@period}").pluck(:metadata).each_with_object({}) do |meta, acc|
        type = meta['drill_type'] || 'unknown'
        acc[type] = (acc[type] || 0) + 1
      end
    end

    def approval_breakdown
      DashboardAnalytic.by_project(@project).by_event('approval_action').send("this_#{@period}").pluck(:metadata).each_with_object({}) do |meta, acc|
        action = meta['action'] || 'unknown'
        acc[action] = (acc[action] || 0) + 1
      end
    end

    def active_users_count
      DashboardAnalytic.by_project(@project).send("this_#{@period}").distinct.count(:user_id)
    end

    def top_users_data
      DashboardAnalytic.by_project(@project)
                       .send("this_#{@period}")
                       .group(:user_id)
                       .select('user_id, COUNT(*) as action_count')
                       .order('action_count DESC')
                       .limit(5)
                       .map do |record|
        user = User.find_by(id: record.user_id)
        {
          user_id: record.user_id,
          user_name: user&.name || 'Unknown',
          actions: record.action_count
        }
      end
    end

    def usage_summary
      total_events = page_views_count + drill_down_breakdown.values.sum + approval_breakdown.values.sum
      {
        total_events: total_events,
        avg_events_per_user: active_users_count.zero? ? 0 : (total_events.to_f / active_users_count).round(1),
        period_label: period_label
      }
    end

    def period_label
      case @period
      when :week
        'This Week'
      when :month
        'This Month'
      else
        'All Time'
      end
    end
  end
end
