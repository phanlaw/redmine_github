# frozen_string_literal: true

class CreateDoraEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :dora_events do |t|
      t.string   :event_type,    null: false  # deploy | incident | recovery
      t.integer  :issue_id
      t.integer  :repository_id
      t.string   :ref
      t.string   :sha
      t.string   :delivery_id                 # X-GitHub-Delivery for idempotency
      t.datetime :occurred_at,   null: false
      t.text     :metadata
      t.datetime :created_at,    null: false
    end

    add_index :dora_events, [:event_type, :occurred_at]
    add_index :dora_events, [:issue_id, :event_type, :occurred_at]
    add_index :dora_events, :delivery_id, unique: true, where: 'delivery_id IS NOT NULL'
  end
end
