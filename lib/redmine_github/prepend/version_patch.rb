# frozen_string_literal: true

module RedmineGithub
  module Prepend
    module VersionPatch
      def self.prepended(base)
        base.validate :qa_signoff_required_for_release
      end

      def qa_signoff_required_for_release
        return unless status_changed? && status == 'locked'
        return if QaSignoff.release_ready?(self)

        errors.add(:base, :qa_signoff_required)
      end
    end
  end
end
