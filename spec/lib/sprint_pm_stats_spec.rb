# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedmineGithub::SprintPmStats do
  def build_version(issues: [])
    version = instance_double(Version, fixed_issues: double('scope'))
    allow(version.fixed_issues).to receive(:includes).and_return(issues)
    version
  end

  def build_issue(closed:, tracker_name:, due_date: nil, closed_on: nil, start_date: nil, priority_id: nil, assigned_to: nil)
    status   = instance_double(IssueStatus, is_closed?: closed)
    tracker  = instance_double(Tracker, name: tracker_name)
    priority = instance_double(IssuePriority)
    assigned = assigned_to || instance_double(User, name: 'Unassigned')
    instance_double(Issue,
      status: status, tracker: tracker, priority: priority, priority_id: priority_id,
      due_date: due_date, closed_on: closed_on, start_date: start_date,
      assigned_to: assigned, created_on: Date.today)
  end

  describe '#call' do
    context 'with no issues' do
      it 'returns empty stats' do
        version = build_version(issues: [])
        stats = described_class.new(version).call
        expect(stats[:total]).to eq(0)
        expect(stats[:completion_rate]).to eq(0.0)
        expect(stats[:bug_rate_ok]).to be true
      end
    end

    context 'with mixed issues' do
      let(:issues) do
        [
          build_issue(closed: true,  tracker_name: 'Feature', due_date: Date.today - 2, closed_on: Date.today - 3, start_date: Date.today - 5),
          build_issue(closed: true,  tracker_name: 'Bug',     due_date: Date.today - 1, closed_on: Date.today,     start_date: Date.today - 2),
          build_issue(closed: false, tracker_name: 'Feature')
        ]
      end

      subject(:stats) { described_class.new(build_version(issues: issues)).call }

      it 'counts total correctly' do
        expect(stats[:total]).to eq(3)
      end

      it 'calculates completion_rate' do
        expect(stats[:completion_rate]).to eq(66.7)
      end

      it 'calculates bug_rate' do
        expect(stats[:bug_rate]).to eq(33.3)
      end

      it 'marks completion_ok false when below threshold' do
        expect(stats[:completion_ok]).to be false
      end

      it 'marks bug_rate_ok false when above threshold' do
        expect(stats[:bug_rate_ok]).to be false
      end

      it 'counts delayed issues (closed_on > due_date)' do
        # closed_on = today, due_date = today-1 → delayed
        expect(stats[:delayed]).to eq(1)
      end
    end

    context 'with all tasks completed on time' do
      let(:issues) do
        Array.new(10) do
          build_issue(closed: true, tracker_name: 'Feature',
            due_date: Date.today, closed_on: Date.today - 1, start_date: Date.today - 3)
        end
      end

      subject(:stats) { described_class.new(build_version(issues: issues)).call }

      it 'has 100% completion rate' do
        expect(stats[:completion_rate]).to eq(100.0)
        expect(stats[:completion_ok]).to be true
      end

      it 'has 0% bug rate' do
        expect(stats[:bug_rate]).to eq(0.0)
        expect(stats[:bug_rate_ok]).to be true
      end

      it 'has 0% delay rate' do
        expect(stats[:delay_rate]).to eq(0.0)
        expect(stats[:delay_rate_ok]).to be true
      end
    end
  end
end
