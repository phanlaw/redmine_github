class CreateSystemSyncStatus < ActiveRecord::Migration[6.1]
  def change
    create_table :system_sync_statuses do |t|
      t.string :source, null: false
      t.datetime :last_sync_at, null: false
      t.datetime :source_updated_at, null: false

      t.timestamps
    end

    add_index :system_sync_statuses, :source, unique: true
    add_index :system_sync_statuses, :last_sync_at
  end
end
