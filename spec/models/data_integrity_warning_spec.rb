require 'rails_helper'

describe DataIntegrityWarning do
  let(:version) { create(:version) }

  describe '.detect_for' do
    it 'deletes old warnings' do
      create(:data_integrity_warning, version: version)
      expect(DataIntegrityWarning.count).to eq(1)

      DataIntegrityWarning.detect_for(version)

      expect(DataIntegrityWarning.for_version(version).count).to eq(0)
    end
  end

  describe 'scopes' do
    it 'filters by version' do
      other_version = create(:version)
      w1 = create(:data_integrity_warning, version: version)
      w2 = create(:data_integrity_warning, version: other_version)

      expect(DataIntegrityWarning.for_version(version)).to contain_exactly(w1)
    end

    it 'filters by warning type' do
      w1 = create(:data_integrity_warning, version: version, warning_type: 'missing_dates')
      w2 = create(:data_integrity_warning, version: version, warning_type: 'pr_without_issue')

      expect(DataIntegrityWarning.by_type('missing_dates')).to contain_exactly(w1)
    end

    it 'orders by detected_at descending' do
      w1 = create(:data_integrity_warning, version: version, detected_at: 1.hour.ago)
      w2 = create(:data_integrity_warning, version: version, detected_at: 10.minutes.ago)

      expect(DataIntegrityWarning.recent).to eq([w2, w1])
    end
  end
end
