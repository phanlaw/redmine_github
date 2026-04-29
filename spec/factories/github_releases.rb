# frozen_string_literal: true

FactoryBot.define do
  factory :github_release, class: RedmineGithub::GithubRelease do
    sequence(:tag_name) { |n| "v1.0.#{n}" }
    name         { tag_name }
    prerelease   { false }
    sequence(:html_url) { |n| "https://github.com/company/repo/releases/tag/v1.0.#{n}" }
    sequence(:repository) { |n| "https://github.com/company/repo#{n}.git" }
    published_at { Time.now }
  end
end
