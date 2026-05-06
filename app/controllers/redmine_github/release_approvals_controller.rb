# frozen_string_literal: true

module RedmineGithub
  class ReleaseApprovalsController < ApplicationController
    before_action :find_project
    before_action :find_version
    before_action :authorize

    def approve_qa
      workflow = RedmineGithub::ApprovalWorkflow.new(@version)
      begin
        workflow.approve_as_qa(User.current, params[:notes])
        DashboardAnalytic.track_approval_action(@project, 'approve', 'qa', User.current)
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    notice: 'QA approval recorded.'
      rescue StandardError => e
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: "QA approval failed: #{e.message}"
      end
    end

    def reject_qa
      workflow = RedmineGithub::ApprovalWorkflow.new(@version)
      begin
        workflow.reject_as_qa(User.current, params[:notes])
        DashboardAnalytic.track_approval_action(@project, 'reject', 'qa', User.current)
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: 'QA approval rejected.'
      rescue StandardError => e
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: "QA rejection failed: #{e.message}"
      end
    end

    def approve_pm
      workflow = RedmineGithub::ApprovalWorkflow.new(@version)
      begin
        workflow.approve_as_pm(User.current, params[:notes])
        DashboardAnalytic.track_approval_action(@project, 'approve', 'pm', User.current)
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    notice: 'PM approval recorded. Sprint ready for production.'
      rescue StandardError => e
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: "PM approval failed: #{e.message}"
      end
    end

    def reject_pm
      workflow = RedmineGithub::ApprovalWorkflow.new(@version)
      begin
        workflow.reject_as_pm(User.current, params[:notes])
        DashboardAnalytic.track_approval_action(@project, 'reject', 'pm', User.current)
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: 'PM approval rejected.'
      rescue StandardError => e
        redirect_to project_pm_dashboard_path(@project, sprint_id: @version.id),
                    alert: "PM rejection failed: #{e.message}"
      end
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_403
    end

    def find_version
      @version = @project.versions.find(params[:version_id])
    rescue ActiveRecord::RecordNotFound
      render_403
    end

    def authorize
      render_403 unless User.current.admin? || @project.users.exists?(User.current.id)
    end
  end
end
