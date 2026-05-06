# frozen_string_literal: true

class CreateDashboardAnalytics < ActiveRecord::Migration[6.0]
  def change
    create_table :dashboard_analytics do |t|
      t.references :project, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: true
      t.string :event_type, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :dashboard_analytics, :event_type
    add_index :dashboard_analytics, :created_at
    add_index :dashboard_analytics, %i[project_id event_type]
    add_index :dashboard_analytics, %i[project_id user_id]
  end
end
