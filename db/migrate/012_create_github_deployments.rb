# frozen_string_literal: true

class CreateGithubDeployments < ActiveRecord::Migration[6.1]
  def change
    create_table :github_deployments do |t|
      t.integer  :issue_id,        null: false
      t.string   :deployment_id,   null: false  # GitHub deployment ID
      t.string   :environment,     null: false
      t.string   :state,           null: false  # pending/in_progress/success/failure/error/inactive
      t.string   :environment_url
      t.string   :log_url
      t.string   :ref
      t.string   :sha
      t.string   :repository
      t.datetime :deployed_at
    end

    add_index :github_deployments, :issue_id
    add_index :github_deployments, [:deployment_id, :issue_id], unique: true
  end
end
