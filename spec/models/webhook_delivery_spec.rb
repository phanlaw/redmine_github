# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhookDelivery do
  describe '.record_delivery' do
    it 'creates new delivery record' do
      repo = create(:github_repository)
      expect {
        described_class.record_delivery('delivery-123', repo, 'push')
      }.to change(described_class, :count).by(1)
    end

    it 'returns existing record on duplicate delivery_id' do
      repo = create(:github_repository)
      first  = described_class.record_delivery('delivery-123', repo, 'push')
      second = described_class.record_delivery('delivery-123', repo, 'push')
      expect(first.id).to eq(second.id)
    end
  end

  describe '.already_processed?' do
    it 'returns true if delivery_id exists' do
      repo = create(:github_repository)
      described_class.record_delivery('delivery-abc', repo, 'push')
      expect(described_class.already_processed?('delivery-abc')).to be true
    end

    it 'returns false if delivery_id not found' do
      expect(described_class.already_processed?('unknown-xyz')).to be false
    end
  end

  describe '.cleanup_stale' do
    it 'deletes deliveries older than 30 days' do
      repo = create(:github_repository)
      old = described_class.create!(delivery_id: 'old-1', repository: repo, event_type: 'push', created_at: 31.days.ago)
      new = described_class.create!(delivery_id: 'new-1', repository: repo, event_type: 'push', created_at: 1.day.ago)

      described_class.cleanup_stale
      expect(described_class.exists?(old.id)).to be false
      expect(described_class.exists?(new.id)).to be true
    end
  end
end
