# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe DoraEvent, type: :model do
  let(:issue) { create(:issue) }

  describe '.record' do
    it 'creates a new event' do
      expect {
        DoraEvent.record(event_type: 'deploy', issue_id: issue.id, occurred_at: Time.current)
      }.to change(DoraEvent, :count).by(1)
    end

    it 'deduplicates by delivery_id' do
      DoraEvent.record(event_type: 'deploy', delivery_id: 'abc-123', occurred_at: Time.current)
      expect {
        DoraEvent.record(event_type: 'deploy', delivery_id: 'abc-123', occurred_at: Time.current)
      }.not_to change(DoraEvent, :count)
    end
  end

  describe '.deployment_frequency' do
    it 'returns deploys per week' do
      from = 4.weeks.ago
      to   = Time.current
      2.times { DoraEvent.create!(event_type: 'deploy', occurred_at: 1.week.ago) }
      freq = DoraEvent.deployment_frequency(from, to)
      expect(freq).to be_a(Numeric)
      expect(freq).to eq(0.5)  # 2 deploys / 4 weeks
    end
  end

  describe '.mttr_minutes' do
    it 'calculates mean time from incident to recovery' do
      incident_time = 60.minutes.ago
      recovery_time = 20.minutes.ago
      branch = 'hotfix/RM-99'

      DoraEvent.create!(event_type: 'incident', issue_id: issue.id, ref: branch, occurred_at: incident_time)
      DoraEvent.create!(event_type: 'recovery', issue_id: issue.id, ref: branch, occurred_at: recovery_time)

      mttr = DoraEvent.mttr_minutes(2.hours.ago, Time.current)
      expect(mttr).to be_within(2.0).of(40.0)  # ~40 minutes
    end

    it 'returns nil with no recovery events' do
      expect(DoraEvent.mttr_minutes(1.week.ago, Time.current)).to be_nil
    end
  end

  describe '.change_failure_rate' do
    it 'calculates percentage of deploys that were hotfixes' do
      branch = 'hotfix/RM-55'
      DoraEvent.create!(event_type: 'incident', issue_id: issue.id, ref: branch, occurred_at: 2.hours.ago)
      DoraEvent.create!(event_type: 'deploy',   issue_id: issue.id, ref: branch, occurred_at: 1.hour.ago)
      DoraEvent.create!(event_type: 'deploy',   issue_id: issue.id, ref: 'feature/other', occurred_at: 30.minutes.ago)

      rate = DoraEvent.change_failure_rate(3.hours.ago, Time.current)
      expect(rate).to eq(50.0)  # 1 of 2 deploys was a hotfix
    end

    it 'returns nil with no deploy events' do
      expect(DoraEvent.change_failure_rate(1.week.ago, Time.current)).to be_nil
    end
  end
end
