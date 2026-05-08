# frozen_string_literal: true

module RedmineGithub
  class PmDashboardController < ApplicationController
    before_action :find_project
    before_action :authorize
    before_action :load_selected_sprint

    def index
      @projects = Project.visible.sorted
      @versions = @project.versions.order(created_on: :desc)

      if @selected_sprint
        DashboardAnalytic.track_page_view(@project, User.current)
        
        @sprint_stats = RedmineGithub::SprintPmStats.new(@selected_sprint).call
        @qa_stats = RedmineGithub::QaGateStats.new(@selected_sprint).call

        sprint_issue_ids   = @selected_sprint.fixed_issues.pluck(:id)
        all_prs            = PullRequest.where(issue_id: sprint_issue_ids)
        @pr_review_stats   = {
          total:  all_prs.count,
          open:   all_prs.where(merged_at: nil).count,
          merged: all_prs.where.not(merged_at: nil).count,
          open_prs: all_prs.where(merged_at: nil).select(:title, :url, :opened_at, :created_at).to_a
        }
        @metric_snapshot = MetricSnapshot.for_version(@selected_sprint).latest.first
        @integrity_warnings = DataIntegrityWarning.for_version(@selected_sprint).recent
        @sync_status = SystemSyncStatus.recent
        @health_summary = RedmineGithub::SprintPmStats.new(@selected_sprint).health_summary
        @release_gate = RedmineGithub::ReleaseReadinessGate.new(
          @selected_sprint,
          health_summary: @health_summary,
          qa_stats: @qa_stats,
          sprint_stats: @sprint_stats
        ).call
        @approval_workflow = RedmineGithub::ApprovalWorkflow.new(@selected_sprint).call
        @audit_trail = RedmineGithub::AuditTrailService.new(@selected_sprint).call
        @trend_analysis = RedmineGithub::TrendAnalysisService.new(@project, 5).call

        needs_attention = []
        @pr_review_stats[:open_prs].each do |pr|
          age = pr.opened_at || pr.created_at
          age_days = age ? ((Time.current - age) / 1.day).to_i : nil
          needs_attention << { type: 'PR', item: pr.title.presence || pr.url, age_days: age_days, url: pr.url }
        end
        unless @qa_stats[:signoff_ok]
          needs_attention << { type: 'QA', item: 'QA sign-off pending', age_days: nil }
        end
        (@sprint_stats[:stale_blockers] + @sprint_stats[:stale_issues]).each do |b|
          age_days = b[:updated_on] ? ((Time.current - b[:updated_on]) / 1.day).to_i : nil
          needs_attention << { type: 'Issue', item: "##{b[:id]} #{b[:subject]}", age_days: age_days, issue_id: b[:id] }
        end
        @needs_attention = needs_attention
          .uniq { |a| [a[:type], a[:url] || a[:issue_id].to_s] }
          .sort_by { |a| -(a[:age_days] || -1) }
      end
    end

    def closed_issues
      authorize_sprint
      DashboardAnalytic.track_drill_down(@project, 'closed_issues', User.current)
      issues = @selected_sprint.fixed_issues.joins(:status).where(issue_statuses: { is_closed: true }).includes(:status, :tracker)
      render_drill_down(issues, "Closed Issues (#{issues.count})")
    end

    def blockers
      authorize_sprint
      DashboardAnalytic.track_drill_down(@project, 'blockers', User.current)
      blocker_statuses = IssueStatus.where(is_closed: false)
      blocker_priorities = IssuePriority.where(name: %w[High Immediate])
      issues = @selected_sprint.fixed_issues.where(status_id: blocker_statuses.pluck(:id), priority_id: blocker_priorities.pluck(:id))
      render_drill_down(issues, "Blockers (#{issues.count})")
    end

    def delayed_tasks
      authorize_sprint
      DashboardAnalytic.track_drill_down(@project, 'delayed_tasks', User.current)
      issues = @selected_sprint.fixed_issues.includes(:status).select do |i|
        i.status.is_closed? && i.due_date && i.closed_on && i.closed_on.to_date > i.due_date
      end
      render_drill_down(issues, "Delayed Tasks (#{issues.count})")
    end

    def failed_tests
      authorize_sprint
      DashboardAnalytic.track_drill_down(@project, 'failed_tests', User.current)
      results = IssueTestResult.where(issue_id: @selected_sprint.fixed_issues.pluck(:id), result: 'failed')
      issues = Issue.where(id: results.pluck(:issue_id))
      render_drill_down(issues, "Failed Tests (#{issues.count})")
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def load_selected_sprint
      sprint_id = params[:sprint_id] || session["pm_dashboard_sprint_#{@project.id}"]
      @selected_sprint = @project.versions.find_by(id: sprint_id) if sprint_id.present?
      @selected_sprint ||= @project.versions.where('effective_date >= ?', Date.today).first
      session["pm_dashboard_sprint_#{@project.id}"] = @selected_sprint.id if @selected_sprint
    end

    def authorize_sprint
      render_403 unless @selected_sprint && @project.versions.exists?(@selected_sprint.id)
    end

    def render_drill_down(issues, title)
      @drill_down_title = title
      @drill_down_issues = issues.sort_by { |i| i.created_on || i.updated_on }.reverse
      respond_to do |format|
        format.html { render 'drill_down' }
        format.json { render json: @drill_down_issues }
      end
    end
  end
end
