# frozen_string_literal: true

module RedmineGithub
  module Include
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        has_one :pull_request, dependent: :destroy
        has_one :issue_test_result, dependent: :destroy
      end
    end
  end
end
