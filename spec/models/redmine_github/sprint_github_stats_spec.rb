# frozen_string_literal: true

require File.expand_path('../../rails_helper', __dir__)

RSpec.describe RedmineGithub::SprintGithubStats do
  let(:project)  { create(:project) }
  let(:version)  { Version.create!(project: project, name: 'Sprint 1', effective_date: Date.today) }
  let(:repo)     { create(:github_repository, project: project) }
  let(:issue1)   { create(:issue, project: project, fixed_version: version) }
  let(:issue2)   { create(:issue, project: project, fixed_version: version) }

  subject(:stats) { described_class.new(version).call }

  context 'no PRs, no commits' do
    it 'returns zeros' do
      expect(stats[:pr_count]).to eq(0)
      expect(stats[:merged_pr_count]).to eq(0)
      expect(stats[:commit_count]).to eq(0)
      expect(stats[:contributors]).to be_empty
      expect(stats[:deploy_count]).to eq(0)
    end
  end

  context 'with pull requests' do
    let!(:merged_pr) do
      create(:pull_request, issue: issue1,
             opened_at: 10.days.ago, merged_at: 5.days.ago)
    end
    let!(:open_pr) do
      create(:pull_request, issue: issue2, opened_at: 3.days.ago, merged_at: nil)
    end

    it 'counts total PRs' do
      expect(stats[:pr_count]).to eq(2)
    end

    it 'counts merged PRs' do
      expect(stats[:merged_pr_count]).to eq(1)
    end

    it 'counts open PRs' do
      expect(stats[:open_pr_count]).to eq(1)
    end

    it 'calculates avg review time' do
      expected = ((merged_pr.merged_at - merged_pr.opened_at) / 3600.0).round(1)
      expect(stats[:avg_review_time_hours]).to eq(expected)
    end

    it 'returns nil avg review time when no merged PR has opened_at' do
      merged_pr.update!(opened_at: nil)
      expect(stats[:avg_review_time_hours]).to be_nil
    end
  end

  context 'with deploy releases' do
    let!(:sprint_issue) { create(:issue, project: project, fixed_version: version, start_date: 14.days.ago.to_date) }
    before { repo } # ensure repo exists + sprint_start non-nil

    let!(:deploy1) { create(:github_release, repository: repo.url, prerelease: false, published_at: 7.days.ago) }
    let!(:deploy2) { create(:github_release, repository: repo.url, prerelease: false, published_at: 2.days.ago) }
    let!(:prerel)  { create(:github_release, repository: repo.url, prerelease: true,  published_at: 1.day.ago) }
    let!(:outside) { create(:github_release, repository: repo.url, prerelease: false, published_at: 20.days.ago) }

    it 'counts production deploys within sprint window' do
      expect(stats[:deploy_count]).to eq(2)
    end

    it 'excludes pre-releases from deploy count' do
      expect(stats[:deploy_count]).to eq(2)
    end

    it 'calculates deploy frequency > 0' do
      expect(stats[:deploy_frequency]).to be > 0
    end
  end

  context 'empty sprint (no issues assigned)' do
    let(:empty_version) { Version.create!(project: project, name: 'Empty Sprint') }

    it 'returns zero counts without error' do
      result = described_class.new(empty_version).call
      expect(result[:pr_count]).to eq(0)
      expect(result[:commit_count]).to eq(0)
      expect(result[:deploy_count]).to eq(0)
    end
  end
end
