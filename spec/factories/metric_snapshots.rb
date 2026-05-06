FactoryBot.define do
  factory :metric_snapshot do
    association :version
    data do
      {
        'completion_rate' => 0.87,
        'completion_ok' => true,
        'bug_rate' => 0.02,
        'bug_rate_ok' => true,
        'delay_rate' => 0.09,
        'delay_rate_ok' => true,
        'avg_cycle_time' => 48,
        'test_execution_rate' => 0.96,
        'test_execution_ok' => true,
        'open_blockers' => 1,
        'blockers_ok' => true,
        'qa_approved' => false,
        'release_ready' => false
      }
    end
    calculated_at { Time.current }
  end
end
