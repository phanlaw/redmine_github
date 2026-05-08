# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project#{n}" }
    identifier { Project.next_identifier || 'project_1' }
    trackers { build_list(:tracker, 1) }

    trait :with_redmine_github do
      after(:create) do |project|
        project.enabled_modules.create!(name: 'redmine_github')
      end
    end
  end
end
