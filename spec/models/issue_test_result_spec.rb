# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe IssueTestResult, type: :model do
  let(:issue)  { create(:issue) }
  let(:tester) { create(:user) }

  describe '.for_issue' do
    it 'initializes a new record when none exists' do
      tr = IssueTestResult.for_issue(issue)
      expect(tr).not_to be_persisted
      expect(tr.issue_id).to eq(issue.id)
      expect(tr.result).to eq('pending')
    end

    it 'returns existing record' do
      existing = IssueTestResult.create!(issue_id: issue.id, result: 'pending')
      expect(IssueTestResult.for_issue(issue).id).to eq(existing.id)
    end
  end

  describe '#pass!' do
    it 'sets result to pass' do
      tr = IssueTestResult.create!(issue_id: issue.id, result: 'pending')
      tr.pass!(tester, notes: 'All good')
      tr.reload
      expect(tr.result).to eq('pass')
      expect(tr.tester_id).to eq(tester.id)
      expect(tr.notes).to eq('All good')
      expect(tr.executed_at).to be_present
    end
  end

  describe '#fail!' do
    it 'sets result to fail' do
      tr = IssueTestResult.create!(issue_id: issue.id, result: 'pending')
      tr.fail!(tester, notes: 'Broken')
      tr.reload
      expect(tr.result).to eq('fail')
    end
  end

  describe '#block!' do
    it 'sets result to blocked' do
      tr = IssueTestResult.create!(issue_id: issue.id, result: 'pending')
      tr.block!(tester)
      tr.reload
      expect(tr.result).to eq('blocked')
    end
  end

  describe '#increment_fix_rounds!' do
    it 'increments fix_rounds counter' do
      tr = IssueTestResult.create!(issue_id: issue.id, result: 'pending', fix_rounds: 0)
      tr.increment_fix_rounds!
      expect(tr.fix_rounds).to eq(1)
      tr.increment_fix_rounds!
      expect(tr.fix_rounds).to eq(2)
    end
  end
end
