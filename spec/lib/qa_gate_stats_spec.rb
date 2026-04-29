# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedmineGithub::QaGateStats do
  def build_issue(closed:, priority_name:, test_result: nil)
    status     = instance_double(IssueStatus, is_closed?: closed)
    tracker    = instance_double(Tracker, name: 'Feature')
    priority   = instance_double(IssuePriority, name: priority_name)
    tr         = test_result ? instance_double(IssueTestResult, result: test_result) : nil
    instance_double(Issue,
      status: status, tracker: tracker, priority: priority,
      issue_test_result: tr)
  end

  def build_version(issues: [], release_ready: false)
    version = instance_double(Version, id: 1)
    issues_scope = double('issues_scope')
    allow(version).to receive(:fixed_issues).and_return(issues_scope)
    allow(issues_scope).to receive(:includes).and_return(issues)
    allow(QaSignoff).to receive(:release_ready?).with(version).and_return(release_ready)
    version
  end

  def with_signoff(version, attrs = {})
    defaults = { status: 'pending', user: nil, approved?: false }
    merged   = defaults.merge(attrs)
    # approved? derives from status unless explicitly passed
    merged[:approved?] = (merged[:status] == 'approved') unless attrs.key?(:approved?)
    signoff = instance_double(QaSignoff, merged)
    allow(QaSignoff).to receive(:for_version).with(version).and_return(signoff)
    signoff
  end

  describe '#call' do
    context 'no issues' do
      it 'returns zero execution rate' do
        version = build_version
        with_signoff(version)
        stats = described_class.new(version).call
        expect(stats[:execution_rate]).to eq(0.0)
        expect(stats[:execution_rate_ok]).to be false
      end
    end

    context 'with tested issues and QA approval' do
      let(:issues) do
        [
          build_issue(closed: true,  priority_name: 'Normal', test_result: 'pass'),
          build_issue(closed: true,  priority_name: 'Normal', test_result: 'pass'),
          build_issue(closed: false, priority_name: 'Normal', test_result: nil)
        ]
      end

      it 'calculates execution_rate' do
        version = build_version(issues: issues)
        with_signoff(version, status: 'approved', user: double(login: 'qa_user'))
        stats = described_class.new(version).call
        expect(stats[:execution_rate]).to eq(66.7)
        expect(stats[:execution_rate_ok]).to be false
      end

      it 'reports signoff approved' do
        version = build_version(issues: issues)
        with_signoff(version, status: 'approved', user: double(login: 'qa_user'))
        stats = described_class.new(version).call
        expect(stats[:signoff_ok]).to be true
      end
    end

    context 'when all issues tested and no blockers' do
      let(:issues) do
        Array.new(20) do
          build_issue(closed: true, priority_name: 'Normal', test_result: 'pass')
        end
      end

      it 'has 100% execution rate' do
        version = build_version(issues: issues, release_ready: true)
        with_signoff(version, status: 'approved', user: double(login: 'qa'))
        stats = described_class.new(version).call
        expect(stats[:execution_rate]).to eq(100.0)
        expect(stats[:execution_rate_ok]).to be true
      end

      it 'marks release_ready true' do
        version = build_version(issues: issues, release_ready: true)
        with_signoff(version, status: 'approved', user: double(login: 'qa'))
        stats = described_class.new(version).call
        expect(stats[:release_ready]).to be true
      end
    end

    context 'when open High-priority issue remains' do
      let(:issues) do
        [build_issue(closed: false, priority_name: 'High', test_result: nil)]
      end

      it 'counts open blocker' do
        version = build_version(issues: issues)
        with_signoff(version)
        stats = described_class.new(version).call
        expect(stats[:open_blockers]).to eq(1)
        expect(stats[:blockers_ok]).to be false
      end
    end
  end
end
