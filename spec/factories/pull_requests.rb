# frozen_string_literal: true

FactoryBot.define do
  factory :pull_request do
    issue
    sequence(:url) { |n| "https://example.com/pull_requests/#{n}" }
    opened_at { nil }
    merged_at { nil }
    mergeable_state { nil }
  end
end
