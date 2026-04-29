# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe 'Version release gate (VersionPatch)', type: :model do
  let(:version) { create(:version, status: 'open') }

  describe 'validation on status change to locked' do
    context 'without QA sign-off' do
      it 'prevents locking the version' do
        version.status = 'locked'
        expect(version).not_to be_valid
      end
    end

    context 'with approved QA sign-off' do
      it 'allows locking the version' do
        QaSignoff.create!(version_id: version.id, status: 'approved')
        version.status = 'locked'
        expect(version).to be_valid
      end
    end

    context 'with rejected QA sign-off' do
      it 'prevents locking the version' do
        QaSignoff.create!(version_id: version.id, status: 'rejected')
        version.status = 'locked'
        expect(version).not_to be_valid
      end
    end

    context 'when status stays open (no change)' do
      it 'does not trigger QA gate' do
        version.name = 'Updated name'
        expect(version).to be_valid
      end
    end
  end
end
