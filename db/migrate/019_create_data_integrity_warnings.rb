class CreateDataIntegrityWarnings < ActiveRecord::Migration[6.1]
  def change
    create_table :data_integrity_warnings do |t|
      t.bigint :version_id, null: false
      t.string :warning_type, null: false
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.datetime :detected_at, null: false

      t.timestamps
    end

    add_index :data_integrity_warnings, :version_id
    add_index :data_integrity_warnings, [:version_id, :warning_type]
    add_index :data_integrity_warnings, [:item_type, :item_id]
    add_foreign_key :data_integrity_warnings, :versions, on_delete: :cascade
  end
end
