# frozen_string_literal: true

module RedmineGithub
  class PmDashboardController < ApplicationController
    before_action :find_project
    before_action :authorize

    def index
      @versions = @project.versions.order(created_on: :desc)

      @sprint_stats = @versions.each_with_object({}) do |v, h|
        h[v.id] = RedmineGithub::SprintPmStats.new(v).call
      end

      @qa_stats = @versions.each_with_object({}) do |v, h|
        h[v.id] = RedmineGithub::QaGateStats.new(v).call
      end
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
