# frozen_string_literal: true

module RedmineGithub
  module Include
    module ChangesetPatch
      def self.included(base)
        base.prepend(InstanceMethods)
      end

      module InstanceMethods
        # Extends Redmine's commit message parser to recognise a configurable
        # prefix pattern as Redmine issue references.
        #
        # With default prefix "RM", these patterns are recognised:
        #   RM-23    RM23    #RM-23    #RM23
        #
        # Works with existing Redmine keywords:
        #   refs RM-23     -> link commit to issue
        #   fixes RM-23    -> link + apply fix action
        #   closes #RM23   -> link + close issue
        def scan_comment_for_issue_ids
          super

          return if comments.blank?

          prefix = Setting.plugin_redmine_github['commit_issue_prefix'].to_s.strip
          return if prefix.blank?

          fix_keywords = Setting.commit_update_keywords_array.pluck('keywords').flatten.compact
          ref_keywords = Setting.commit_ref_keywords.downcase.split(',').map(&:strip)
          ref_keywords_any = ref_keywords.delete('*')
          all_keywords = (ref_keywords + fix_keywords).uniq

          kw_re = all_keywords.map { |k| Regexp.escape(k) }.join('|')
          prefix_re = Regexp.escape(prefix)
          # Matches optional keyword, then #?PREFIX-?N
          pattern = /(?:(#{kw_re})[\s:]+)?\#?#{prefix_re}-?(\d+)\b/i

          already_linked = self.issues.to_a.dup

          comments.scan(pattern) do |keyword, id|
            next unless keyword.present? || ref_keywords_any

            issue = find_referenced_issue_by_id(id.to_i)
            next unless issue
            next if issue_linked_to_same_commit?(issue) || already_linked.include?(issue)

            already_linked << issue

            next if repository.created_on && committed_on && committed_on < repository.created_on

            action = keyword.to_s.strip.downcase
            fix_issue(issue, action) if fix_keywords.include?(action)
          end

          already_linked.uniq!
          self.issues = already_linked unless already_linked.empty?
        end
      end
    end
  end
end
