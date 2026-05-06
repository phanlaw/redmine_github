class CreateMetricSnapshots < ActiveRecord::Migration[6.1]
  def change
    create_table :metric_snapshots do |t|
      t.bigint :version_id, null: false
      t.json :data, null: false, default: {}
      t.datetime :calculated_at, null: false

      t.timestamps
    end

    add_index :metric_snapshots, :version_id
    add_index :metric_snapshots, [:version_id, :calculated_at], order: { calculated_at: :desc }
    add_foreign_key :metric_snapshots, :versions, on_delete: :cascade
  end
end
