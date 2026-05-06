# frozen_string_literal: true

module RedmineGithub
  class DashboardAnalyticsController < ApplicationController
    before_action :find_project
    before_action :authorize

    def index
      @analytics_week = RedmineGithub::AnalyticsService.new(@project, :week).call
      @analytics_month = RedmineGithub::AnalyticsService.new(@project, :month).call
      @analytics_all = RedmineGithub::AnalyticsService.new(@project, :all).call
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_403
    end

    def authorize
      render_403 unless User.current.admin? || @project.users.exists?(User.current.id)
    end
  end
end
