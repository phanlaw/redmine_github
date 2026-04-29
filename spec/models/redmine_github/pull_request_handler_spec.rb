# frozen_string_literal: true

require File.expand_path('../../rails_helper', __dir__)

RSpec.describe RedmineGithub::PullRequestHandler do
  let(:repository) { create(:github_repository) }

  describe '.transition_issue_status' do
    let!(:status_new)         { create(:issue_status, id: 1, name: 'New') }
    let!(:status_in_progress) { create(:issue_status, id: 2, name: 'In Progress') }
    let!(:status_resolved)    { create(:issue_status, id: 3, name: 'Resolved') }
    let!(:status_in_review)   { create(:issue_status, id: 7, name: 'In Review') }
    let!(:status_qa_testing)  { create(:issue_status, id: 8, name: 'QA Testing') }

    def payload_for(issue, action, merged: false)
      {
        'pull_request' => {
          'action'   => action,
          'merged'   => merged,
          'html_url' => 'https://github.com/company/repo/pull/1',
          'head'     => { 'ref' => "feature/RM-#{issue.id}-test" }
        }
      }
    end

    context 'opened — issue is New (1)' do
      let(:issue) { create(:issue, status: status_new) }

      it 'moves issue to In Review (7)' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'opened'))
        expect(issue.reload.status_id).to eq(7)
      end
    end

    context 'opened — issue is already QA Testing (8)' do
      let(:issue) { create(:issue, status: status_qa_testing) }

      it 'does not move issue backwards' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'opened'))
        expect(issue.reload.status_id).to eq(8)
      end
    end

    context 'closed with merged=true — issue is In Review (7)' do
      let(:issue) { create(:issue, status: status_in_review) }

      it 'moves issue to Resolved (3)' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'closed', merged: true))
        expect(issue.reload.status_id).to eq(3)
      end
    end

    context 'closed without merge — issue is In Review (7)' do
      let(:issue) { create(:issue, status: status_in_review) }

      it 'moves issue back to In Progress (2)' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'closed', merged: false))
        expect(issue.reload.status_id).to eq(2)
      end
    end

    context 'closed without merge — issue is already Resolved (3)' do
      let(:issue) { create(:issue, status: status_resolved) }

      it 'does not change status' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'closed', merged: false))
        expect(issue.reload.status_id).to eq(3)
      end
    end

    context 'reopened — issue is Resolved (3)' do
      let(:issue) { create(:issue, status: status_resolved) }

      it 'moves issue to In Review and increments fix_rounds' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'reopened'))
        expect(issue.reload.status_id).to eq(7)
        tr = IssueTestResult.find_by(issue_id: issue.id)
        expect(tr).to be_present
        expect(tr.fix_rounds).to eq(1)
      end

      it 'accumulates fix_rounds on multiple reopens' do
        2.times { RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'reopened')) }
        expect(IssueTestResult.find_by(issue_id: issue.id).fix_rounds).to eq(2)
      end
    end

    context 'reopened — issue is New (1)' do
      let(:issue) { create(:issue, status: status_new) }

      it 'moves to In Review but does not create fix_rounds record' do
        RedmineGithub::PullRequestHandler.transition_issue_status(issue, payload_for(issue, 'reopened'))
        expect(issue.reload.status_id).to eq(7)
        expect(IssueTestResult.find_by(issue_id: issue.id)).to be_nil
      end
    end
  end

  describe '.handle pull_request' do
    subject { RedmineGithub::PullRequestHandler.handle(repository, 'pull_request', payload) }

    context 'action is "opened"' do
      let(:payload) do
        {
          'pull_request' => {
            'action'   => 'opened',
            'html_url' => url,
            'head' => {
              'ref' => ref
            },
            'merged_at' => merged_at,
            'merged'    => false
          }
        }
      end
      let(:url) { 'https://github.com/company/repo/pull/1' }
      let(:issue) { create :issue }
      let(:merged_at) { nil }

      context 'when the branch has an issue ID' do
        let(:ref) { "feature/@#{issue.id}-my_first_pr" }

        before { allow_any_instance_of(PullRequest).to receive(:sync) }

        it { expect { subject }.to change { PullRequest.exists?(url: url, issue_id: issue.id) }.to true }
        it { expect { subject }.to change(PullRequest, :count).by(1) }
      end

      context 'when the branch does not have an issue ID' do
        let(:ref) { "feature/#{issue.id}-my_first_pr" }

        it { expect { subject }.not_to change(PullRequest, :count) }
      end

      context 'when a issue has pull request' do
        let(:ref) { "feature/@#{issue.id}-my_first_pr" }
        let!(:repository) { create :github_repository, url: 'https://github.com/company/repo.git' }
        let!(:pull_request) { create :pull_request, issue: issue, url: url }

        before do
          expect_any_instance_of(PullRequest).to receive(:sync)
        end

        it { expect { subject }.to_not change(PullRequest, :count) }
      end
    end
  end

  describe '.handle pull_request_review' do
    subject { RedmineGithub::PullRequestHandler.handle(repository, 'pull_request_review', payload) }

    let(:payload) { {} }

    it {
      expect(RedmineGithub::PullRequestHandler).to(
        receive(:handle_pull_request).with(repository, payload)
      )
      subject
    }
  end

  describe '.handle push' do
    subject { RedmineGithub::PullRequestHandler.handle(repository, 'push', payload) }

    let(:payload) { { 'ref' => ref } }
    let!(:issue) { create :issue }
    let!(:pull_request) { create :pull_request, issue: issue }

    context 'related issues exists' do
      let(:ref) { "feature/@#{issue.id}" }

      it do
        expect_any_instance_of(PullRequest).to receive(:sync)
        subject
      end
    end

    context 'related issues not exists' do
      let(:ref) { "feature/#{issue.id}" }

      it do
        expect_any_instance_of(PullRequest).to_not receive(:sync)
        subject
      end
    end
  end

  describe '.handle status' do
    subject { RedmineGithub::PullRequestHandler.handle(repository, 'status', payload) }

    let(:payload) { { 'branches' => [{ name: branch }] } }
    let!(:issue) { create :issue }
    let!(:pull_request) { create :pull_request, issue: issue }

    context 'related issues exists' do
      let(:branch) { "feature/@#{issue.id}" }

      it do
        expect_any_instance_of(PullRequest).to receive(:sync).and_return(true)
        subject
      end
    end

    context 'related issues not exists' do
      let(:branch) { "feature/#{issue.id}" }

      it do
        expect_any_instance_of(PullRequest).to_not receive(:sync)
        subject
      end
    end
  end

  describe '.hotfix_issue_id' do
    it 'extracts issue ID from hotfix/RM-NNN' do
      expect(described_class.hotfix_issue_id('hotfix/RM-42')).to eq(42)
    end

    it 'extracts issue ID from hotfix/RM-NNN-description' do
      expect(described_class.hotfix_issue_id('hotfix/RM-42-null-pointer')).to eq(42)
    end

    it 'returns nil for non-hotfix branches' do
      expect(described_class.hotfix_issue_id('feature/RM-42-foo')).to be_nil
    end
  end

  describe 'hotfix flow' do
    let!(:status_new)         { create(:issue_status, id: 1, name: 'New') }
    let!(:status_in_progress) { create(:issue_status, id: 2, name: 'In Progress') }
    let!(:status_closed)      { create(:issue_status, id: 5, name: 'Closed') }
    let!(:status_in_review)   { create(:issue_status, id: 7, name: 'In Review') }
    let(:issue)               { create(:issue, status: status_in_review) }

    describe 'push — new hotfix branch' do
      it 'logs an incident DoraEvent' do
        payload = {
          'ref'    => "refs/heads/hotfix/RM-#{issue.id}",
          'before' => '0000000000000000000000000000000000000000',
          'after'  => 'abc123'
        }
        expect {
          described_class.handle_push(repository, payload)
        }.to change(DoraEvent.incidents, :count).by(1)

        event = DoraEvent.incidents.last
        expect(event.issue_id).to eq(issue.id)
        expect(event.ref).to eq("hotfix/RM-#{issue.id}")
      end

      it 'moves New issue to In Progress' do
        new_issue = create(:issue, status: status_new)
        payload = {
          'ref'    => "refs/heads/hotfix/RM-#{new_issue.id}",
          'before' => '0' * 40,
          'after'  => 'abc123'
        }
        described_class.handle_push(repository, payload)
        expect(new_issue.reload.status_id).to eq(2)
      end

      it 'does NOT log incident on regular push (non-zero before)' do
        payload = {
          'ref'    => "refs/heads/hotfix/RM-#{issue.id}",
          'before' => 'deadbeef0000000000000000000000000000000000',
          'after'  => 'abc123'
        }
        expect {
          described_class.handle_push(repository, payload)
        }.not_to change(DoraEvent, :count)
      end
    end

    describe 'pull_request closed+merged — hotfix branch' do
      let(:merged_at) { 30.minutes.ago.iso8601 }
      let(:payload) do
        {
          'pull_request' => {
            'action'           => 'closed',
            'merged'           => true,
            'html_url'         => "https://github.com/org/repo/pull/5",
            'number'           => 5,
            'title'            => "Fix null pointer RM-#{issue.id}",
            'head'             => { 'ref' => "hotfix/RM-#{issue.id}" },
            'merge_commit_sha' => 'deadbeef',
            'merged_at'        => merged_at
          },
          'repository' => { 'full_name' => 'org/repo' }
        }
      end

      before do
        # Pre-create an incident event
        DoraEvent.create!(
          event_type:  'incident',
          issue_id:    issue.id,
          ref:         "hotfix/RM-#{issue.id}",
          occurred_at: 2.hours.ago
        )
        # Stub backport PR creation so tests don't hit the network
        allow(described_class).to receive(:create_backport_pr)
      end

      it 'closes the issue directly (status 5, bypassing QA)' do
        described_class.transition_issue_status(issue, payload, repository: repository)
        expect(issue.reload.status_id).to eq(5)
      end

      it 'logs a deploy DoraEvent' do
        expect {
          described_class.transition_issue_status(issue, payload, repository: repository)
        }.to change(DoraEvent.deploys, :count).by(1)
      end

      it 'logs a recovery DoraEvent when incident exists' do
        expect {
          described_class.transition_issue_status(issue, payload, repository: repository)
        }.to change(DoraEvent.recoveries, :count).by(1)
      end
    end
  end

  describe '.extract_issue_id' do
    subject { RedmineGithub::PullRequestHandler.extract_issue_id(branch_name) }

    context 'when branch_name has an @{issue_id}' do
      let(:branch_name) { 'feature/@1234-my_first_pr' }
      it { is_expected.to eq 1234 }
    end

    context 'when branch_name has a number without @' do
      let(:branch_name) { 'feature/1234-my_first_pr' }
      it { is_expected.to be_nil }
    end
  end
end
