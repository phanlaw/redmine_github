require 'rails_helper'

describe SystemSyncStatus do
  describe '#update_sync' do
    it 'creates sync record with timestamps' do
      record = SystemSyncStatus.update_sync('redmine', 2.hours.ago)

      expect(record).to be_persisted
      expect(record.source).to eq('redmine')
      expect(record.last_sync_at).to be_within(1.second).of(Time.current)
      expect(record.source_updated_at).to be_within(1.second).of(2.hours.ago)
    end

    it 'updates existing sync record' do
      first = SystemSyncStatus.update_sync('github', 3.hours.ago)
      sleep 0.1
      second = SystemSyncStatus.update_sync('github', 1.hour.ago)

      expect(SystemSyncStatus.count).to eq(1)
      expect(second.id).to eq(first.id)
      expect(second.last_sync_at).to be > first.last_sync_at
    end

    it 'rejects invalid source' do
      expect {
        SystemSyncStatus.update_sync('invalid_source')
      }.to raise_error("Invalid source: invalid_source")
    end
  end

  describe '#stale?' do
    it 'returns true if last_sync_at older than 1 hour' do
      record = create(:system_sync_status, last_sync_at: 2.hours.ago)
      expect(record.stale?).to be true
    end

    it 'returns false if last_sync_at within 1 hour' do
      record = create(:system_sync_status, last_sync_at: 30.minutes.ago)
      expect(record.stale?).to be false
    end
  end

  describe '#freshness_label' do
    it 'displays "Just now" for sync within 5 minutes' do
      record = create(:system_sync_status, last_sync_at: 2.minutes.ago)
      expect(record.freshness_label).to eq('Just now')
    end

    it 'displays minutes for sync within 1 hour' do
      record = create(:system_sync_status, last_sync_at: 30.minutes.ago)
      expect(record.freshness_label).to match(/\d+m ago/)
    end

    it 'displays hours for sync within 1 day' do
      record = create(:system_sync_status, last_sync_at: 6.hours.ago)
      expect(record.freshness_label).to match(/\d+h ago/)
    end

    it 'displays days for older sync' do
      record = create(:system_sync_status, last_sync_at: 3.days.ago)
      expect(record.freshness_label).to match(/\d+d ago/)
    end
  end

  describe 'scopes' do
    it 'filters by source' do
      create(:system_sync_status, source: 'redmine')
      create(:system_sync_status, source: 'github')
      create(:system_sync_status, source: 'qa_signoff')

      expect(SystemSyncStatus.by_source('github').pluck(:source)).to eq(['github'])
    end

    it 'orders by last_sync_at descending' do
      old = create(:system_sync_status, source: 'redmine', last_sync_at: 1.hour.ago)
      sleep 0.05
      new = create(:system_sync_status, source: 'github', last_sync_at: 5.minutes.ago)

      expect(SystemSyncStatus.recent.first.id).to eq(new.id)
      expect(SystemSyncStatus.recent.last.id).to eq(old.id)
    end
  end
end
