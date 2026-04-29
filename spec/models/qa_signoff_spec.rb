# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe QaSignoff, type: :model do
  let(:version) { create(:version) }
  let(:user)    { create(:user) }

  describe '.for_version' do
    it 'initializes a new record when none exists' do
      signoff = QaSignoff.for_version(version)
      expect(signoff).not_to be_persisted
      expect(signoff.version_id).to eq(version.id)
      expect(signoff.status).to eq('pending')
    end

    it 'returns existing record' do
      existing = QaSignoff.create!(version_id: version.id, status: 'pending')
      expect(QaSignoff.for_version(version).id).to eq(existing.id)
    end
  end

  describe '.release_ready?' do
    it 'returns false when no signoff exists' do
      expect(QaSignoff.release_ready?(version)).to be false
    end

    it 'returns false when signoff is pending' do
      QaSignoff.create!(version_id: version.id, status: 'pending')
      expect(QaSignoff.release_ready?(version)).to be false
    end

    it 'returns false when signoff is rejected' do
      QaSignoff.create!(version_id: version.id, status: 'rejected')
      expect(QaSignoff.release_ready?(version)).to be false
    end

    it 'returns true when signoff is approved' do
      QaSignoff.create!(version_id: version.id, status: 'approved')
      expect(QaSignoff.release_ready?(version)).to be true
    end
  end

  describe '#approve!' do
    it 'sets status to approved and records user + time' do
      signoff = QaSignoff.create!(version_id: version.id, status: 'pending')
      signoff.approve!(user, notes: 'LGTM')
      signoff.reload
      expect(signoff.status).to eq('approved')
      expect(signoff.user_id).to eq(user.id)
      expect(signoff.notes).to eq('LGTM')
      expect(signoff.signed_off_at).to be_present
    end
  end

  describe '#reject!' do
    it 'sets status to rejected with reason' do
      signoff = QaSignoff.create!(version_id: version.id, status: 'approved')
      signoff.reject!(user, notes: 'Bug found')
      signoff.reload
      expect(signoff.status).to eq('rejected')
      expect(signoff.notes).to eq('Bug found')
    end
  end
end
