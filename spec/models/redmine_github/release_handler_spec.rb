# frozen_string_literal: true

require File.expand_path('../../rails_helper', __dir__)

RSpec.describe RedmineGithub::ReleaseHandler do
  let(:repository) { create(:github_repository, url: 'https://github.com/co/repo.git') }

  subject { described_class.new(repository, payload).handle }

  let(:base_release) do
    {
      'tag_name'     => 'v1.2.3',
      'name'         => 'Release 1.2.3',
      'prerelease'   => false,
      'html_url'     => 'https://github.com/co/repo/releases/tag/v1.2.3',
      'published_at' => '2026-04-01T10:00:00Z'
    }
  end

  context 'action is published' do
    let(:payload) { { 'action' => 'published', 'release' => base_release } }

    it 'creates a GithubRelease record' do
      expect { subject }.to change(RedmineGithub::GithubRelease, :count).by(1)
    end

    it 'stores correct attributes' do
      subject
      release = RedmineGithub::GithubRelease.last
      expect(release.tag_name).to eq('v1.2.3')
      expect(release.prerelease).to be false
      expect(release.repository).to eq(repository.url)
      expect(release.published_at).to be_within(1.second).of(Time.parse('2026-04-01T10:00:00Z'))
    end

    it 'is idempotent — does not duplicate on repeat' do
      subject
      expect { described_class.new(repository, payload).handle }.not_to change(RedmineGithub::GithubRelease, :count)
    end

    context 'when release is a prerelease' do
      let(:payload) { { 'action' => 'published', 'release' => base_release.merge('prerelease' => true) } }

      it 'stores prerelease flag' do
        subject
        expect(RedmineGithub::GithubRelease.last.prerelease).to be true
      end
    end
  end

  context 'action is not published' do
    let(:payload) { { 'action' => 'deleted', 'release' => base_release } }

    it 'does not create a record' do
      expect { subject }.not_to change(RedmineGithub::GithubRelease, :count)
    end
  end

  context 'payload missing release key' do
    let(:payload) { { 'action' => 'published' } }

    it 'does not create a record' do
      expect { subject }.not_to change(RedmineGithub::GithubRelease, :count)
    end
  end
end
