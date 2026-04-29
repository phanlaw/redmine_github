# frozen_string_literal: true

module RedmineGithub
  module GithubApi
    module Rest
      class Repos
        def initialize(access_token)
          @access_token = access_token
        end

        def current_user
          Client.new("#{END_POINT}/user", @access_token).get
        end

        def list_orgs
          Client.new("#{END_POINT}/user/orgs?per_page=100", @access_token).get
        end

        def list_for_user(page: 1)
          Client.new("#{END_POINT}/user/repos?per_page=100&page=#{page}&sort=updated&affiliation=owner,organization_member", @access_token).get
        end

        def list_for_org(org, page: 1)
          Client.new("#{END_POINT}/orgs/#{org}/repos?per_page=100&page=#{page}&sort=updated&type=all", @access_token).get
        end
      end
    end
  end
end
