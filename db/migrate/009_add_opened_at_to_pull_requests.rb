# frozen_string_literal: true

class AddOpenedAtToPullRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :pull_requests, :opened_at, :datetime
  end
end
