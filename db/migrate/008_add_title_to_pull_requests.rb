# frozen_string_literal: true

class AddTitleToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :pull_requests, :title, :string
  end
end
