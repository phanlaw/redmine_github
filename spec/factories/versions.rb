# frozen_string_literal: true

FactoryBot.define do
  factory :version do
    sequence(:name) { |n| "v#{n}.0" }
    association :project
    status { 'open' }
    sharing { 'none' }
  end
end
