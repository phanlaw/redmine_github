class CreateProjectThresholds < ActiveRecord::Migration[6.1]
  def change
    create_table :project_thresholds do |t|
      t.integer :project_id, null: false
      t.decimal :completion_ok, precision: 5, scale: 2, default: 85.00
      t.decimal :completion_warning, precision: 5, scale: 2, default: 70.00
      t.decimal :bug_rate_ok, precision: 5, scale: 2, default: 3.00
      t.decimal :bug_rate_warning, precision: 5, scale: 2, default: 5.00
      t.decimal :delay_rate_ok, precision: 5, scale: 2, default: 10.00
      t.decimal :delay_rate_warning, precision: 5, scale: 2, default: 20.00
      t.decimal :cycle_time_baseline_days, precision: 8, scale: 2, default: nil
      t.timestamps
    end

    add_index :project_thresholds, :project_id, unique: true
  end
end
