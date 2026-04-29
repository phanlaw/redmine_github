# frozen_string_literal: true

module RedmineGithub
  class SprintGithubStats
    attr_reader :version

    def initialize(version)
      @version = version
    end

    def call
      {
        pr_count:            pr_count,
        merged_pr_count:     merged_pr_count,
        open_pr_count:       pr_count - merged_pr_count,
        commit_count:        commit_count,
        contributors:        contributors,
        avg_cycle_time_hours:  avg_cycle_time_hours,
        avg_review_time_hours: avg_review_time_hours,
        issues_with_pr:      issues_with_pr_count,
        issues_with_commits: issues_with_commits_count
      }
    end

    private

    def sprint_issues
      @sprint_issues ||= version.fixed_issues
    end

    def sprint_issue_ids
      @sprint_issue_ids ||= sprint_issues.pluck(:id)
    end

    def sprint_prs
      @sprint_prs ||= PullRequest.where(issue_id: sprint_issue_ids)
    end

    def sprint_changesets
      @sprint_changesets ||= begin
        return Changeset.none if sprint_issue_ids.empty?

        Changeset
          .joins("INNER JOIN changesets_issues ON changesets_issues.changeset_id = changesets.id")
          .joins("INNER JOIN repositories ON repositories.id = changesets.repository_id")
          .where("changesets_issues.issue_id IN (?)", sprint_issue_ids)
          .where("repositories.type = ?", "Repository::Github")
          .distinct
      end
    end

    def pr_count
      @pr_count ||= sprint_prs.count
    end

    def merged_pr_count
      @merged_pr_count ||= sprint_prs.where.not(merged_at: nil).count
    end

    def commit_count
      @commit_count ||= sprint_changesets.count
    end

    def contributors
      @contributors ||= sprint_changesets
        .where.not(committer: [nil, ''])
        .distinct
        .pluck(:committer)
        .uniq
    end

    def issues_with_pr_count
      @issues_with_pr_count ||= sprint_prs.select(:issue_id).distinct.count
    end

    def issues_with_commits_count
      return 0 if sprint_issue_ids.empty?

      Changeset
        .joins("INNER JOIN changesets_issues ON changesets_issues.changeset_id = changesets.id")
        .joins("INNER JOIN repositories ON repositories.id = changesets.repository_id")
        .where("changesets_issues.issue_id IN (?)", sprint_issue_ids)
        .where("repositories.type = ?", "Repository::Github")
        .distinct("changesets_issues.issue_id")
        .count("DISTINCT changesets_issues.issue_id")
    end

    def avg_cycle_time_hours
      merged = sprint_prs.where.not(merged_at: nil)
                         .joins(:issue)
                         .select("pull_requests.merged_at, pull_requests.opened_at, issues.created_on")
                         .to_a

      return nil if merged.empty?

      total_hours = merged.sum do |pr|
        ((pr.merged_at - pr.created_on) / 3600.0).round(1)
      end

      (total_hours / merged.size).round(1)
    end

    def avg_review_time_hours
      merged = sprint_prs.where.not(merged_at: nil, opened_at: nil).to_a
      return nil if merged.empty?

      total = merged.sum { |pr| ((pr.merged_at - pr.opened_at) / 3600.0) }
      (total / merged.size).round(1)
    end
  end
end
