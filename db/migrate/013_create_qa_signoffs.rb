# frozen_string_literal: true

class CreateQaSignoffs < ActiveRecord::Migration[7.0]
  def change
    create_table :qa_signoffs do |t|
      t.integer  :version_id,    null: false
      t.integer  :user_id
      t.string   :status,        null: false, default: 'pending'
      t.text     :notes
      t.datetime :signed_off_at
      t.timestamps
    end
    add_index :qa_signoffs, :version_id, unique: true
  end
end
