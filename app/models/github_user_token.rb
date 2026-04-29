# frozen_string_literal: true

class GithubUserToken < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
  validates :github_login, presence: true
  validates :access_token, presence: true
end
