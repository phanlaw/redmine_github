module RedmineGithub
  class ReleaseHandler
    def initialize(repository, payload)
      @repository = repository
      @payload    = payload
    end

    def handle
      return unless @payload['action'] == 'published'

      release = @payload['release']
      return unless release

      GithubRelease.find_or_create_by(
        tag_name:   release['tag_name'],
        repository: @repository.url
      ) do |r|
        r.name         = release['name']
        r.prerelease   = release['prerelease'] || false
        r.html_url     = release['html_url']
        r.published_at = Time.parse(release['published_at'])
      end
    end
  end
end
