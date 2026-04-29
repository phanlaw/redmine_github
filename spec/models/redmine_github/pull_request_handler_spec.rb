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
