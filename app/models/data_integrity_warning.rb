class DataIntegrityWarning < ApplicationRecord
  belongs_to :version

  WARNING_TYPES = %w[
    missing_linked_issue
    done_but_unmerged
    missing_dates
    pr_without_issue
    no_test_result
  ].freeze

  validates :version_id, presence: true
  validates :warning_type, presence: true, inclusion: { in: WARNING_TYPES }
  validates :item_type, presence: true
  validates :item_id, presence: true

  scope :for_version, ->(version) { where(version_id: version.id) }
  scope :recent, -> { order(detected_at: :desc) }
  scope :by_type, ->(type) { where(warning_type: type) }

  def self.detect_for(version)
    delete_for(version)

    issues = version.fixed_issues.includes(:status, :pull_requests, :custom_fields).to_a
    pull_requests = PullRequest.where(issue_id: issues.pluck(:id))

    detect_pr_without_issue(version, pull_requests)
    detect_done_but_unmerged(version, issues)
    detect_missing_dates(version, issues)
    detect_no_test_result(version, issues)
  end

  def self.delete_for(version)
    where(version_id: version.id).delete_all
  end

  private

  def self.detect_pr_without_issue(version, prs)
    prs.each do |pr|
      next if pr.issue_id.present?

      create!(
        version_id: version.id,
        warning_type: 'pr_without_issue',
        item_type: 'PullRequest',
        item_id: pr.id,
        detected_at: Time.current
      )
    end
  end

  def self.detect_done_but_unmerged(version, issues)
    issues.each do |issue|
      next unless issue.status.is_closed?
      next if issue.pull_requests.where(merged_at: ..Float::INFINITY).any?
      next if issue.pull_requests.empty?

      create!(
        version_id: version.id,
        warning_type: 'done_but_unmerged',
        item_type: 'Issue',
        item_id: issue.id,
        detected_at: Time.current
      )
    end
  end

  def self.detect_missing_dates(version, issues)
    issues.each do |issue|
      next if issue.start_date.present? && issue.due_date.present?
      next unless issue.status.is_closed?

      create!(
        version_id: version.id,
        warning_type: 'missing_dates',
        item_type: 'Issue',
        item_id: issue.id,
        detected_at: Time.current
      )
    end
  end

  def self.detect_no_test_result(version, issues)
    issues.each do |issue|
      next if IssueTestResult.where(issue_id: issue.id).any?
      next unless issue.status.is_closed?

      create!(
        version_id: version.id,
        warning_type: 'no_test_result',
        item_type: 'Issue',
        item_id: issue.id,
        detected_at: Time.current
      )
    end
  end
end
