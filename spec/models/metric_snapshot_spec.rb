require 'rails_helper'

describe MetricSnapshot do
  let(:version) { create(:version) }

  describe '#calculate_for' do
    it 'creates snapshot with calculated metrics' do
      snapshot = MetricSnapshot.calculate_for(version)

      expect(snapshot).to be_persisted
      expect(snapshot.version_id).to eq(version.id)
      expect(snapshot.data).to include('completion_rate', 'bug_rate', 'delay_rate', 'avg_cycle_time')
      expect(snapshot.calculated_at).to be_within(1.second).of(Time.current)
    end

    it 'stores all metric fields in data hash' do
      snapshot = MetricSnapshot.calculate_for(version)

      data = snapshot.data
      expect(data).to have_key('completion_ok')
      expect(data).to have_key('bug_rate_ok')
      expect(data).to have_key('delay_rate_ok')
      expect(data).to have_key('test_execution_ok')
      expect(data).to have_key('release_ready')
    end
  end

  describe 'scopes' do
    let!(:snapshot1) { create(:metric_snapshot, version: version, calculated_at: 2.days.ago) }
    let!(:snapshot2) { create(:metric_snapshot, version: version, calculated_at: 1.day.ago) }

    it 'filters by version' do
      other_version = create(:version)
      create(:metric_snapshot, version: other_version)

      expect(MetricSnapshot.for_version(version)).to contain_exactly(snapshot1, snapshot2)
    end

    it 'returns latest snapshot' do
      expect(MetricSnapshot.latest.first).to eq(snapshot2)
    end

    it 'filters since time' do
      expect(MetricSnapshot.since(1.5.days.ago)).to contain_exactly(snapshot2)
    end
  end

  describe 'data accessors' do
    let(:snapshot) do
      create(:metric_snapshot, version: version, data: {
        'completion_rate' => 0.85,
        'bug_rate' => 0.02,
        'delay_rate' => 0.08,
        'avg_cycle_time' => 48,
        'open_blockers' => 2,
        'release_ready' => true
      })
    end

    it 'accesses nested data fields' do
      expect(snapshot.completion_rate).to eq(0.85)
      expect(snapshot.bug_rate).to eq(0.02)
      expect(snapshot.delay_rate).to eq(0.08)
      expect(snapshot.avg_cycle_time).to eq(48)
      expect(snapshot.open_blockers).to eq(2)
      expect(snapshot.release_ready?).to be true
    end
  end
end
