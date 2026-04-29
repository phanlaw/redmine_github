# frozen_string_literal: true

module RedmineGithub
  module PullRequestHandler
    module_function

    def handle(repository, event, payload)
      send("handle_#{event}", repository, payload)
    end

    # Detect hotfix branch and extract issue ID.
    # Supports: hotfix/RM-NNN, hotfix/RM-NNN-*, hotfix/NNN
    def hotfix_issue_id(ref)
      match = ref.to_s.match(%r{hotfix/(?:RM-?)?(\d+)}i)
      match ? match.captures[0].to_i : nil
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

    def handle_pull_request(repository, payload)
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
        transition_issue_status(issue, payload, repository: repository)
      end
    end

    # Transition Redmine issue status based on PR action.
    # Only advances status — never moves backwards past a later stage
    # (e.g., won't move a QA-approved issue back to In Review).
    #
    # Status IDs: 1=New, 2=In Progress, 3=Resolved, 7=In Review, 8=QA Testing, 9=QA Approved, 5=Closed
    def transition_issue_status(issue, payload, repository: nil)
      action  = payload.dig('pull_request', 'action').to_s
      merged  = payload.dig('pull_request', 'merged')
      ref     = payload.dig('pull_request', 'head', 'ref').to_s
      delivery = payload.dig('headers', 'x-github-delivery') || payload.dig('_delivery_id')

      case action
      when 'opened', 'synchronize'
        # Move to In Review only if issue is New or In Progress
        Issue.where(id: issue.id).update_all(status_id: 7) if [1, 2].include?(issue.status_id)
      when 'reopened'
        # PR reopened after close — if issue was Resolved/QA stage, track a fix round
        if [3, 8, 9].include?(issue.status_id)
          tr = IssueTestResult.for_issue(issue)
          tr.save! unless tr.persisted?
          tr.increment_fix_rounds!
        end
        Issue.where(id: issue.id).update_all(status_id: 7) if [1, 2, 3].include?(issue.status_id)
      when 'closed'
        if merged
          if hotfix_issue_id(ref) == issue.id
            # Hotfix merge: close directly (bypass QA) + log DORA events
            Issue.where(id: issue.id).update_all(status_id: 5)
            handle_hotfix_merged(issue, payload, repository: repository, delivery: delivery)
          else
            # Normal merge → Resolved (if not already QA Testing / QA Approved / Closed)
            Issue.where(id: issue.id).update_all(status_id: 3) if [1, 2, 7].include?(issue.status_id)
          end
        else
          # Closed without merge → revert to In Progress if currently In Review
          Issue.where(id: issue.id).update_all(status_id: 2) if issue.status_id == 7
        end
      end
    rescue StandardError => e
      Rails.logger.error "[redmine_github] status transition failed for issue ##{issue.id}: #{e.message}"
    end

    def handle_pull_request_review(repository, payload)
      handle_pull_request(repository, payload)
    end

    def handle_push(repository, payload)
      ref        = payload.dig('ref').to_s
      delivery   = payload.dig('headers', 'x-github-delivery') || payload.dig('_delivery_id')

      # Detect new hotfix branch creation (before == all-zeros means new branch)
      before = payload.dig('before').to_s
      if before.match?(/\A0+\z/) && (hf_id = hotfix_issue_id(ref))
        hf_issue = Issue.find_by(id: hf_id)
        branch   = ref.sub('refs/heads/', '')
        DoraEvent.record(
          event_type:    'incident',
          delivery_id:   delivery.present? ? "push-incident-#{delivery}" : nil,
          issue_id:      hf_issue&.id,
          repository_id: repository.id,
          ref:           branch,
          sha:           payload.dig('after'),
          occurred_at:   Time.current
        )
        # Move issue to In Progress if still New
        Issue.where(id: hf_id, status_id: 1).update_all(status_id: 2)
      end

      issue = Issue.find_by(id: extract_issue_id(ref))
      return if issue.blank?

      PullRequest.where(issue: issue).find_each(&:sync)
      repository.fetch_changesets
    end

    def handle_status(_repository, payload)
      issue_ids = payload.dig('branches').map { |b| extract_issue_id(b[:name]) }.compact.uniq
      PullRequest.where(issue_id: issue_ids).find_each(&:sync)
    end

    def handle_hotfix_merged(issue, payload, repository:, delivery:)
      ref       = payload.dig('pull_request', 'head', 'ref').to_s
      sha       = payload.dig('pull_request', 'merge_commit_sha')
      merged_at = payload.dig('pull_request', 'merged_at')
      occurred  = merged_at ? Time.parse(merged_at) : Time.current
      repo_id   = repository&.id

      DoraEvent.record(
        event_type:    'deploy',
        delivery_id:   delivery.present? ? "pr-deploy-#{delivery}" : nil,
        issue_id:      issue.id,
        repository_id: repo_id,
        ref:           ref,
        sha:           sha,
        occurred_at:   occurred
      )

      # Find the matching incident (latest for this issue + ref)
      incident = DoraEvent.incidents
                          .where(issue_id: issue.id, ref: ref)
                          .where(occurred_at: ..occurred)
                          .order(occurred_at: :desc)
                          .first

      if incident
        DoraEvent.record(
          event_type:    'recovery',
          delivery_id:   delivery.present? ? "pr-recovery-#{delivery}" : nil,
          issue_id:      issue.id,
          repository_id: repo_id,
          ref:           ref,
          sha:           sha,
          occurred_at:   occurred
        )

        mttr_mins = ((occurred - incident.occurred_at) / 60.0).round(1)
        add_hotfix_journal_note(issue, mttr_mins, payload)
      end

      create_backport_pr(repository, payload) if repository
    rescue StandardError => e
      Rails.logger.error "[redmine_github] hotfix DORA logging failed for issue ##{issue.id}: #{e.message}"
    end

    def add_hotfix_journal_note(issue, mttr_mins, payload)
      pr_url  = payload.dig('pull_request', 'html_url')
      branch  = payload.dig('pull_request', 'head', 'ref')
      journal = Journal.new(
        journalized:  issue,
        user:         User.anonymous,
        notes:        "🚀 **Hotfix deployed** via [#{branch}](#{pr_url})\n\n" \
                      "MTTR: **#{mttr_mins} minutes**"
      )
      journal.save
    rescue StandardError => e
      Rails.logger.warn "[redmine_github] could not add hotfix journal note: #{e.message}"
    end

    def create_backport_pr(repository, payload)
      cred = repository.github_credential
      return unless cred&.token.present?

      full_name = payload.dig('repository', 'full_name')
      head_ref  = payload.dig('pull_request', 'head', 'ref')
      pr_title  = payload.dig('pull_request', 'title')
      pr_number = payload.dig('pull_request', 'number')

      uri = URI("https://api.github.com/repos/#{full_name}/pulls")
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{cred.token}")
      req.body = {
        title: "[Backport] #{pr_title}",
        head:  head_ref,
        base:  'develop',
        body:  "Automated backport of ##{pr_number} to develop."
      }.to_json

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(req)
      end
    rescue StandardError => e
      Rails.logger.warn "[redmine_github] backport PR creation failed: #{e.message}"
    end
  end
end
