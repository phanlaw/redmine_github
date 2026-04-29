# frozen_string_literal: true

require File.expand_path('../../rails_helper', __dir__)

RSpec.describe RedmineGithub::DeploymentStatusHandler do
  let(:repository) { create(:github_repository) }
  let(:issue)      { create(:issue) }

  def payload_for(ref:, state:, environment: 'production', dep_id: 99)
    {
      'deployment_status' => {
        'id'              => dep_id * 10,
        'state'           => state,
        'environment'     => environment,
        'environment_url' => "https://#{environment}.example.com",
        'log_url'         => "https://github.com/org/repo/actions/runs/#{dep_id}",
        'created_at'      => '2026-04-30T00:00:00Z'
      },
      'deployment' => {
        'id'  => dep_id,
        'ref' => ref,
        'sha' => 'abc123def456'
      },
      'repository' => { 'html_url' => 'https://github.com/org/repo' }
    }
  end

  context 'ref encodes issue ID' do
    let(:ref) { "feature/RM-#{issue.id}-deploy-me" }

    it 'creates a GithubDeployment record' do
      expect {
        RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'success'))
      }.to change(GithubDeployment, :count).by(1)
    end

    it 'stores correct attributes' do
      RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'success'))
      dep = GithubDeployment.last
      expect(dep.issue_id).to    eq(issue.id)
      expect(dep.state).to       eq('success')
      expect(dep.environment).to eq('production')
      expect(dep.environment_url).to eq('https://production.example.com')
    end

    it 'updates existing record on repeat (idempotent)' do
      RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'in_progress', dep_id: 42))
      RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'success',     dep_id: 42))
      expect(GithubDeployment.count).to eq(1)
      expect(GithubDeployment.last.state).to eq('success')
    end

    it 'records staging deployments separately' do
      RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'success', environment: 'production', dep_id: 1))
      RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: ref, state: 'success', environment: 'staging',    dep_id: 2))
      expect(GithubDeployment.count).to eq(2)
    end
  end

  context 'ref not linked to any issue' do
    it 'does not create any record' do
      expect {
        RedmineGithub::DeploymentStatusHandler.handle(repository, payload_for(ref: 'main', state: 'success'))
      }.not_to change(GithubDeployment, :count)
    end
  end

  context 'deployment_status key missing' do
    it 'does not raise' do
      expect {
        RedmineGithub::DeploymentStatusHandler.handle(repository, {})
      }.not_to raise_error
    end
  end
end
