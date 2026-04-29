# frozen_string_literal: true

class IssueTestResult < ActiveRecord::Base
  belongs_to :issue
  belongs_to :tester, class_name: 'User', foreign_key: :tester_id, optional: true

  RESULTS = %w[pending pass fail blocked].freeze

  validates :issue_id, presence: true
  validates :result, inclusion: { in: RESULTS }

  scope :passed,  -> { where(result: 'pass') }
  scope :failed,  -> { where(result: 'fail') }
  scope :blocked, -> { where(result: 'blocked') }

  def self.for_issue(issue)
    find_or_initialize_by(issue_id: issue.id)
  end

  def pass!(tester, notes: nil)
    assign_attributes(tester_id: tester.id, result: 'pass',
                      notes: notes, executed_at: Time.current)
    save!
  end

  def fail!(tester, notes: nil)
    assign_attributes(tester_id: tester.id, result: 'fail',
                      notes: notes, executed_at: Time.current)
    save!
  end

  def block!(tester, notes: nil)
    assign_attributes(tester_id: tester.id, result: 'blocked',
                      notes: notes, executed_at: Time.current)
    save!
  end

  # Called when a PR re-opens a resolved issue — tracks rework cycles
  def increment_fix_rounds!
    IssueTestResult.where(id: id).update_all('fix_rounds = fix_rounds + 1')
    reload
  end

  def pending? = result == 'pending'
  def pass?    = result == 'pass'
  def fail?    = result == 'fail'
  def blocked? = result == 'blocked'
end
