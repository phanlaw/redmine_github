# frozen_string_literal: true

class AddCiStatusToPullRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :pull_requests, :ci_status, :string
    add_column :pull_requests, :ci_run_url, :string
  end
end
