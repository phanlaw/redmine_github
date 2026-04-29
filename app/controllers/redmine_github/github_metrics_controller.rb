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

      repo_ids      = @github_repos.pluck(:id)
      quarter_range = DoraEvent.current_quarter_range
      @dora = {
        range:                  quarter_range,
        deployment_frequency:   DoraEvent.deploys.where(repository_id: repo_ids).then { |s|
                                  DoraEvent.deployment_frequency(quarter_range.begin, quarter_range.end) },
        mttr_minutes:           DoraEvent.mttr_minutes(quarter_range.begin, quarter_range.end),
        change_failure_rate:    DoraEvent.change_failure_rate(quarter_range.begin, quarter_range.end)
      }
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
