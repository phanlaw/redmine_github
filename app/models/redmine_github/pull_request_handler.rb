# frozen_string_literal: true

module RedmineGithub
  module PullRequestHandler
    module_function

    def handle(repository, event, payload)
      send("handle_#{event}", repository, payload)
    end

    # Legacy: extract a single issue ID from @N pattern in branch names.
    def extract_issue_id(branch_name)
      match = branch_name.to_s.match(/@(\d+)/)
      return nil unless match

      match.captures[0].to_i
    end

    # Extract Redmine issue IDs from arbitrary text using the configured prefix
    # (default "RM"). Recognises: RM-23, RM23, #RM-23, #RM23.
    # Also falls back to legacy @N pattern for backward compatibility.
    def extract_issue_ids_from_text(text, prefix)
      prefix_re = Regexp.escape(prefix)
      text.to_s.scan(/#?#{prefix_re}-?(\d+)/i).flatten.map(&:to_i)
    end

    # Collect all Redmine issues referenced in a pull_request payload by
    # scanning the branch name, PR title, and PR body.
    def extract_issues_from_pr_payload(payload)
      prefix = Setting.plugin_redmine_github['commit_issue_prefix'].to_s.strip
      prefix = 'RM' if prefix.blank?

      sources = [
        payload.dig('pull_request', 'head', 'ref'),
        payload.dig('pull_request', 'title'),
        payload.dig('pull_request', 'body')
      ]

      ids = sources.flat_map { |s| extract_issue_ids_from_text(s, prefix) }

      # Legacy @N pattern in branch name
      legacy_id = extract_issue_id(payload.dig('pull_request', 'head', 'ref'))
      ids << legacy_id if legacy_id

      Issue.where(id: ids.uniq.compact).to_a
    end

    def handle_pull_request(_repository, payload)
      issues = extract_issues_from_pr_payload(payload)
      return if issues.empty?

      url       = payload.dig('pull_request', 'html_url')
      title     = payload.dig('pull_request', 'title')
      opened_at = payload.dig('pull_request', 'created_at')

      issues.each do |issue|
        pr = PullRequest.find_or_create_by(issue: issue, url: url)
        pr.update(
          title:     title.presence || pr.title,
          opened_at: pr.opened_at || (opened_at ? Time.parse(opened_at) : nil)
        )
        pr.sync
      end
    end

    def handle_pull_request_review(repository, payload)
      handle_pull_request(repository, payload)
    end

    def handle_push(repository, payload)
      issue = Issue.find_by(id: extract_issue_id(payload.dig('ref')))
      return if issue.blank?

      PullRequest.where(issue: issue).find_each(&:sync)
      repository.fetch_changesets
    end

    def handle_status(_repository, payload)
      issue_ids = payload.dig('branches').map { |b| extract_issue_id(b[:name]) }.compact.uniq
      PullRequest.where(issue_id: issue_ids).find_each(&:sync)
    end
  end
end
