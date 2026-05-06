FactoryBot.define do
  factory :data_integrity_warning do
    association :version
    warning_type { 'missing_dates' }
    item_type { 'Issue' }
    item_id { 1 }
    detected_at { Time.current }
  end
end
