# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RedmineGithub::WorkflowRunHandler do
  let(:repository) { create(:github_repository) }
  let(:issue)      { create(:issue) }
  let(:pr)         { create(:pull_request, issue: issue, url: "https://github.com/org/repo/pull/10") }

  def payload_for(branch:, conclusion:, repo_url: 'https://github.com/org/repo')
    {
      'workflow_run' => {
        'head_branch' => branch,
        'conclusion'  => conclusion,
        'html_url'    => "#{repo_url}/actions/runs/999"
      },
      'repository' => { 'html_url' => repo_url }
    }
  end

  before { pr } # ensure PR exists

  context 'branch encodes issue ID via configured prefix' do
    let(:branch) { "feature/RM-#{issue.id}-some-work" }

    it 'updates ci_status to success' do
      RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: branch, conclusion: 'success'))
      expect(pr.reload.ci_status).to eq('success')
    end

    it 'sets ci_run_url' do
      RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: branch, conclusion: 'failure'))
      expect(pr.reload.ci_run_url).to eq('https://github.com/org/repo/actions/runs/999')
    end

    it 'updates ci_status to failure' do
      RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: branch, conclusion: 'failure'))
      expect(pr.reload.ci_status).to eq('failure')
    end

    it 'sets pending when conclusion is nil' do
      RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: branch, conclusion: nil))
      expect(pr.reload.ci_status).to eq('pending')
    end
  end

  context 'branch uses legacy @N pattern' do
    let(:branch) { "feature/@#{issue.id}-old-style" }

    it 'updates ci_status' do
      RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: branch, conclusion: 'success'))
      expect(pr.reload.ci_status).to eq('success')
    end
  end

  context 'branch not linked to any issue' do
    it 'does not raise and updates nothing' do
      expect {
        RedmineGithub::WorkflowRunHandler.handle(repository, payload_for(branch: 'main', conclusion: 'success'))
      }.not_to raise_error
    end
  end

  context 'workflow_run key missing from payload' do
    it 'does not raise' do
      expect {
        RedmineGithub::WorkflowRunHandler.handle(repository, {})
      }.not_to raise_error
    end
  end
end
