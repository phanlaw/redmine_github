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

      # For GitHub-backed changesets, rewires reference rendering:
      #   #N      -> link to GitHub issue #N
      #   #RMN    -> link to Redmine issue #N  (prefix configurable)
      #
      # Strategy: replace both patterns with STX/ETX-delimited placeholders
      # before calling super (using a skip-tags regex so HTML attributes are
      # never touched), then restore as the appropriate links afterward.
      def parse_redmine_links(text, default_project, obj, attr, only_path, options)
        github_repo = obj.is_a?(Changeset) && obj.repository.is_a?(Repository::Github) ? obj.repository : nil
        return super unless github_repo

        github_base = github_repo.url.sub(/\.git\z/, '')
        prefix      = Setting.plugin_redmine_github['commit_issue_prefix'].to_s.strip
        return super if prefix.blank?
        prefix_re   = Regexp.escape(prefix)

        # Replace #RMN / #RM-N first (more specific), skipping HTML tags
        text.gsub!(/(<[^>]+>)|(?<![\/\w&#])##{prefix_re}-?(\d+)(?!\w)/i) do |m|
          $1 ? m : "\x02RM#{$2}\x03"
        end

        # Replace plain #N (GitHub refs), skipping HTML tags
        text.gsub!(/(<[^>]+>)|(?<![\/\w&#])#(\d+)(?!\w)/) do |m|
          $1 ? m : "\x02GH#{$2}\x03"
        end

        super

        # Restore Redmine placeholders
        text.gsub!(/\x02RM(\d+)\x03/) do
          issue_id = $1.to_i
          issue    = Issue.visible.find_by_id(issue_id)
          if issue
            url   = issue_url(issue, :only_path => only_path)
            title = ERB::Util.h("#{issue.tracker.name} ##{issue_id}: #{issue.subject} (#{issue.status.name})")
            "<a href=\"#{url}\" class=\"#{issue.css_classes}\" title=\"#{title}\">##{prefix}-#{issue_id}</a>"
          else
            "##{prefix}-#{issue_id}"
          end
        end

        # Restore GitHub placeholders
        text.gsub!(/\x02GH(\d+)\x03/) do
          num = $1
          url = "#{github_base}/issues/#{num}"
          "<a href=\"#{url}\" class=\"github-issue-link\" target=\"_blank\" rel=\"noopener\">##{num}</a>"
        end
      end
    end
  end
end
