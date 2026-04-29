# frozen_string_literal: true

module RedmineGithub
  module Prepend
    module ApplicationHelperPatch
      def link_to_revision(revision, repository, options = {})
        result = super
        repo = repository.is_a?(Project) ? repository.repository : repository
        return result unless repo.is_a?(Repository::Github)

        rev = revision.respond_to?(:identifier) ? revision.identifier : revision
        github_url = repo.commit_url(rev)
        return result if github_url.blank?

        result + ' '.html_safe +
          link_to('(GitHub)', github_url, target: '_blank', rel: 'noopener noreferrer',
                                          title: 'View commit on GitHub', class: 'github-commit-link')
      end
    end
  end
end
