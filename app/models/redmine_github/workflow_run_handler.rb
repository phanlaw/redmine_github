# frozen_string_literal: true

module RedmineGithub
  module WorkflowRunHandler
    module_function

    # Payload shape from GitHub `workflow_run` event:
    # {
    #   "workflow_run" => {
    #     "head_branch"       => "feature/RM-42-pr-lifecycle",
    #     "conclusion"        => "success"|"failure"|"cancelled"|nil,
    #     "html_url"          => "https://github.com/org/repo/actions/runs/123",
    #     "pull_requests"     => [{"number" => 1, ...}]
    #   },
    #   "repository" => { "html_url" => "https://github.com/org/repo" }
    # }

    CONCLUSIONS = %w[success failure cancelled skipped timed_out action_required].freeze

    def handle(_repository, payload)
      run      = payload['workflow_run'] || payload.dig('workflow_run') || return
      branch   = run['head_branch'].to_s
      status   = run['conclusion'].presence || 'pending'
      run_url  = run['html_url']
      repo_url = payload.dig('repository', 'html_url')

      return if branch.blank?

      pull_requests = find_pull_requests_for_branch(branch, repo_url)
      pull_requests.each do |pr|
        pr.update_columns(ci_status: status, ci_run_url: run_url)
      end

      Rails.logger.info "[redmine_github] workflow_run #{status} on #{branch} → updated #{pull_requests.size} PR(s)"
    rescue StandardError => e
      Rails.logger.error "[redmine_github] WorkflowRunHandler error: #{e.message}"
    end

    def find_pull_requests_for_branch(branch, repo_html_url)
      scope = PullRequest.joins(:issue)
      if repo_html_url.present?
        # Match PRs whose URL starts with the repo's GitHub URL + /pull/
        scope = scope.where("url LIKE ?", "#{repo_html_url}/pull/%")
      end

      # Match by head branch pattern encoded in PR url or linked issue
      issue_ids = extract_issue_ids_from_branch(branch)
      if issue_ids.any?
        scope.where(issue_id: issue_ids)
      else
        PullRequest.none
      end
    end

    def extract_issue_ids_from_branch(branch)
      prefix = Setting.plugin_redmine_github['commit_issue_prefix'].to_s.strip
      prefix = 'RM' if prefix.blank?
      ids = PullRequestHandler.extract_issue_ids_from_text(branch, prefix)
      # Also try legacy @N pattern
      legacy = branch.match(/@(\d+)/)&.captures&.first.to_i
      ids |= [legacy] if legacy > 0
      ids
    end
  end
end
