module RedmineGithub
  class GithubRelease < ActiveRecord::Base
    self.table_name = 'github_releases'

    scope :for_repository, ->(repo) { where(repository: repo) }
    scope :production,     -> { where(prerelease: false) }
    scope :between,        ->(from, to) { where(published_at: from..to) }
  end
end
