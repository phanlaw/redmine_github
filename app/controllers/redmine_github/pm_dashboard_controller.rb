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
        @sprint_stats = RedmineGithub::SprintPmStats.new(@selected_sprint).call
        @qa_stats = RedmineGithub::QaGateStats.new(@selected_sprint).call
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
      end
    end

    def closed_issues
      authorize_sprint
      issues = @selected_sprint.fixed_issues.joins(:status).where(issue_statuses: { is_closed: true }).includes(:status, :tracker)
      render_drill_down(issues, "Closed Issues (#{issues.count})")
    end

    def blockers
      authorize_sprint
      blocker_statuses = IssueStatus.where(is_closed: false)
      blocker_priorities = IssuePriority.where(name: %w[High Immediate])
      issues = @selected_sprint.fixed_issues.where(status_id: blocker_statuses.pluck(:id), priority_id: blocker_priorities.pluck(:id))
      render_drill_down(issues, "Blockers (#{issues.count})")
    end

    def delayed_tasks
      authorize_sprint
      issues = @selected_sprint.fixed_issues.includes(:status).select do |i|
        i.status.is_closed? && i.due_date && i.closed_on && i.closed_on.to_date > i.due_date
      end
      render_drill_down(issues, "Delayed Tasks (#{issues.count})")
    end

    def failed_tests
      authorize_sprint
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
