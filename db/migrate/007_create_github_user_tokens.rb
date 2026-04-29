# frozen_string_literal: true

class CreateGithubUserTokens < ActiveRecord::Migration[6.1]
  def change
    create_table :github_user_tokens do |t|
      t.integer :user_id, null: false
      t.string :github_login, null: false
      t.text :access_token, null: false
      t.string :token_type, default: 'bearer'
      t.string :scopes

      t.timestamps
    end

    add_index :github_user_tokens, :user_id, unique: true
    add_index :github_user_tokens, :github_login
  end
end
