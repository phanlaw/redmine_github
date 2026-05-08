# frozen_string_literal: true

FactoryBot.define do
  factory :approval_log do
    association :version
    association :user
    action { 'approve' }
    role { 'QA' }
    status { 'approved' }
    notes { nil }
  end
end
