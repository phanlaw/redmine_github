FactoryBot.define do
  factory :system_sync_status do
    source { %w[redmine github qa_signoff].sample }
    last_sync_at { 1.hour.ago }
    source_updated_at { 1.hour.ago }
  end
end
