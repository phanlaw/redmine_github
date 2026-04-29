# frozen_string_literal: true

class CreateIssueTestResults < ActiveRecord::Migration[7.0]
  def change
    create_table :issue_test_results do |t|
      t.integer  :issue_id,   null: false
      t.integer  :tester_id
      t.string   :result,     null: false, default: 'pending'
      t.text     :notes
      t.integer  :fix_rounds, null: false, default: 0
      t.datetime :executed_at
      t.timestamps
    end
    add_index :issue_test_results, :issue_id, unique: true
  end
end
