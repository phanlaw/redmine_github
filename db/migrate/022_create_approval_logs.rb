class CreateApprovalLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :approval_logs do |t|
      t.integer :version_id, null: false
      t.integer :user_id, null: false
      t.string :action, null: false
      t.string :role, null: false
      t.string :status, null: false
      t.text :notes
      t.timestamps
    end

    add_index :approval_logs, [:version_id, :created_at]
    add_index :approval_logs, :user_id
    add_index :approval_logs, :action
  end
end
