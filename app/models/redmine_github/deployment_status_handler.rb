# frozen_string_literal: true

module RedmineGithub
  module DeploymentStatusHandler
    module_function

    # GitHub `deployment_status` payload:
    # {
    #   "deployment_status" => {
    #     "id"              => 123,
    #     "state"           => "success"|"failure"|"pending"|"in_progress"|"queued"|"error"|"inactive",
    #     "environment"     => "production"|"staging"|...,
    #     "environment_url" => "https://...",
    #     "log_url"         => "https://...",
    #     "created_at"      => "2026-04-30T00:00:00Z"
    #   },
    #   "deployment" => {
    #     "id"  => 99,
    #     "ref" => "main"|"feature/RM-42-...",
    #     "sha" => "abc123"
    #   },
    #   "repository" => { "html_url" => "https://github.com/org/repo" }
    # }

    def handle(_repository, payload)
      ds    = payload['deployment_status'] || return
      dep   = payload['deployment']        || return
      state = ds['state'].to_s
      env   = ds['environment'].to_s
      ref   = dep['ref'].to_s
      sha   = dep['sha'].to_s
      repo  = payload.dig('repository', 'html_url').to_s

      return if ref.blank? || env.blank?

      issues = find_issues_for_ref(ref)
      return if issues.empty?

      deployed_at = Time.parse(ds['created_at']) rescue Time.current

      issues.each do |issue|
        record = GithubDeployment.find_or_initialize_by(
          deployment_id: dep['id'].to_s,
          issue_id:      issue.id
        )
        record.assign_attributes(
          environment:     env,
          state:           state,
          environment_url: ds['environment_url'],
          log_url:         ds['log_url'],
          ref:             ref,
          sha:             sha,
          repository:      repo,
          deployed_at:     deployed_at
        )
        record.save!
      end

      Rails.logger.info "[redmine_github] deployment_status #{state} on #{env} (#{ref}) → #{issues.size} issue(s)"
    rescue StandardError => e
      Rails.logger.error "[redmine_github] DeploymentStatusHandler error: #{e.message}"
    end

    def find_issues_for_ref(ref)
      prefix = Setting.plugin_redmine_github['commit_issue_prefix'].to_s.strip
      prefix = 'RM' if prefix.blank?
      ids = PullRequestHandler.extract_issue_ids_from_text(ref, prefix)
      legacy = ref.match(/@(\d+)/)&.captures&.first.to_i
      ids |= [legacy] if legacy > 0
      return [] if ids.empty?

      Issue.where(id: ids).to_a
    end
  end
end
