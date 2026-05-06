class CreateReleaseApprovals < ActiveRecord::Migration[6.1]
  def change
    create_table :release_approvals do |t|
      t.integer :version_id, null: false
      t.integer :user_id, null: false
      t.string :role, null: false
      t.string :status, null: false, default: 'pending'
      t.text :notes
      t.datetime :approved_at
      t.timestamps
    end

    add_index :release_approvals, [:version_id, :role], unique: true
    add_index :release_approvals, :user_id
    add_index :release_approvals, :status
  end
end
