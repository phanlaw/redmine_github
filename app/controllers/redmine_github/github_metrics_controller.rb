# frozen_string_literal: true

module RedmineGithub
  class GithubMetricsController < ApplicationController
    before_action :find_project
    before_action :authorize

    def index
      @github_repos = Repository::Github.where(project: @project)
      @versions     = @project.versions.order(created_on: :desc)

      @stats_by_version = @versions.each_with_object({}) do |version, h|
        h[version.id] = RedmineGithub::SprintGithubStats.new(version).call
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
