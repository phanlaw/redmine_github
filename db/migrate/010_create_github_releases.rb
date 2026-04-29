class CreateGithubReleases < ActiveRecord::Migration[6.0]
  def change
    create_table :github_releases do |t|
      t.string  :tag_name,    null: false
      t.string  :name
      t.boolean :prerelease,  default: false, null: false
      t.string  :html_url
      t.string  :repository
      t.datetime :published_at, null: false
    end

    add_index :github_releases, :published_at
    add_index :github_releases, :repository
  end
end
