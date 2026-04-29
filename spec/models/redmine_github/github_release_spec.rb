# frozen_string_literal: true

require File.expand_path('../../rails_helper', __dir__)

RSpec.describe RedmineGithub::GithubRelease do
  describe 'scopes' do
    let!(:prod_release)   { create(:github_release, prerelease: false, repository: 'https://github.com/co/repo.git', published_at: 3.days.ago) }
    let!(:pre_release)    { create(:github_release, prerelease: true,  repository: 'https://github.com/co/repo.git', published_at: 2.days.ago) }
    let!(:other_repo)     { create(:github_release, prerelease: false, repository: 'https://github.com/co/other.git', published_at: 1.day.ago) }

    describe '.production' do
      it 'excludes pre-releases' do
        expect(described_class.production).to include(prod_release, other_repo)
        expect(described_class.production).not_to include(pre_release)
      end
    end

    describe '.for_repository' do
      it 'filters by repository url' do
        result = described_class.for_repository('https://github.com/co/repo.git')
        expect(result).to include(prod_release, pre_release)
        expect(result).not_to include(other_repo)
      end
    end

    describe '.between' do
      it 'returns releases within date range' do
        result = described_class.between(4.days.ago, 2.5.days.ago)
        expect(result).to include(prod_release)
        expect(result).not_to include(pre_release, other_repo)
      end
    end
  end
end
