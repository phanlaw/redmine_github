# frozen_string_literal: true

module RedmineGithub
  class QaSignoffsController < ApplicationController
    before_action :require_login
    before_action :find_version
    before_action :authorize_qa

    def create
      @signoff = QaSignoff.for_version(@version)
      @signoff.assign_attributes(status: 'pending')
      @signoff.save!
      redirect_to version_path, notice: l(:notice_qa_signoff_created)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to version_path, alert: e.message
    end

    def approve
      @signoff = QaSignoff.for_version(@version)
      @signoff.approve!(User.current, notes: params[:notes])
      redirect_to version_path, notice: l(:notice_qa_approved)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to version_path, alert: e.message
    end

    def reject
      @signoff = QaSignoff.for_version(@version)
      @signoff.reject!(User.current, notes: params[:notes])
      redirect_to version_path, notice: l(:notice_qa_rejected)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to version_path, alert: e.message
    end

    private

    def find_version
      @version = Version.find(params[:version_id])
      @project = @version.project
    end

    def authorize_qa
      deny_access unless User.current.allowed_to?(:manage_qa_signoffs, @project)
    end

    def version_path
      project_version_path(@project, @version)
    end
  end
end
