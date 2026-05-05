# frozen_string_literal: true

class CreateWebhookDeliveries < ActiveRecord::Migration[6.0]
  def change
    create_table :webhook_deliveries do |t|
      t.string :delivery_id, null: false, index: { unique: true }
      t.references :repository, polymorphic: true, index: true
      t.string :event_type, null: false
      t.datetime :created_at, null: false
    end

    # Auto-cleanup: delete deliveries older than 30 days to prevent table bloat
    add_index :webhook_deliveries, :created_at
  end
end
