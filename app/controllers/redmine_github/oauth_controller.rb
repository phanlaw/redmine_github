# frozen_string_literal: true

module RedmineGithub
  class OauthController < ApplicationController
    before_action :require_login

    GITHUB_AUTHORIZE_URL = 'https://github.com/login/oauth/authorize'
    GITHUB_TOKEN_URL     = 'https://github.com/login/oauth/access_token'

    def authorize
      client_id = plugin_setting('github_oauth_client_id')
      return render_error(message: l(:error_redmine_github_oauth_not_configured), status: 422) if client_id.blank?

      state = SecureRandom.hex(16)
      session[:github_oauth_state] = state
      session[:github_oauth_return_to] = params[:return_to]

      redirect_to "#{GITHUB_AUTHORIZE_URL}?client_id=#{client_id}&scope=repo,admin:repo_hook&state=#{state}", allow_other_host: true
    end

    def callback
      unless params[:state] == session.delete(:github_oauth_state)
        return render_error(message: l(:error_redmine_github_oauth_state_mismatch), status: 422)
      end

      return_to = session.delete(:github_oauth_return_to) || { controller: 'settings', action: 'plugin', id: 'redmine_github' }

      code = params[:code]
      token_data = exchange_code_for_token(code)

      if token_data.nil? || token_data['access_token'].blank?
        return render_error(message: l(:error_redmine_github_oauth_token_exchange_failed), status: 422)
      end

      access_token = token_data['access_token']
      github_user = fetch_github_user(access_token)

      if github_user.nil?
        return render_error(message: l(:error_redmine_github_oauth_user_fetch_failed), status: 422)
      end

      token = GithubUserToken.find_or_initialize_by(user_id: User.current.id)
      token.update!(
        github_login: github_user['login'],
        access_token: access_token,
        token_type:   token_data['token_type'] || 'bearer',
        scopes:       token_data['scope']
      )

      flash[:notice] = l(:notice_redmine_github_oauth_connected, login: github_user['login'])
      redirect_to return_to
    end

    def disconnect
      GithubUserToken.where(user_id: User.current.id).destroy_all
      flash[:notice] = l(:notice_redmine_github_oauth_disconnected)
      redirect_back(fallback_location: { controller: 'my', action: 'account' })
    end

    def repos
      token = GithubUserToken.find_by(user_id: User.current.id)
      return render json: { error: 'not_connected' }, status: :unauthorized if token.nil?

      client = GithubApi::Rest::Repos.new(token.access_token)

      org = params[:org]
      page = params[:page]&.to_i || 1

      repos = if org.present?
                client.list_for_org(org, page: page)
              else
                client.list_for_user(page: page)
              end

      render json: repos.map { |r|
        {
          full_name: r['full_name'],
          name:      r['name'],
          private:   r['private'],
          clone_url: r['clone_url']
        }
      }
    rescue GithubApi::Rest::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

    def orgs
      token = GithubUserToken.find_by(user_id: User.current.id)
      return render json: { error: 'not_connected' }, status: :unauthorized if token.nil?

      client = GithubApi::Rest::Repos.new(token.access_token)
      github_user = client.current_user
      orgs = client.list_orgs

      accounts = [{ login: github_user['login'], avatar_url: github_user['avatar_url'], type: 'User' }]
      accounts += orgs.map { |o| { login: o['login'], avatar_url: o['avatar_url'], type: 'Organization' } }

      render json: accounts
    rescue GithubApi::Rest::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

    private

    def plugin_setting(key)
      ::Setting.plugin_redmine_github[key.to_s]
    end

    def exchange_code_for_token(code)
      client_id     = plugin_setting('github_oauth_client_id')
      client_secret = plugin_setting('github_oauth_client_secret')

      uri = URI.parse(GITHUB_TOKEN_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/json'
      request.body = { client_id: client_id, client_secret: client_secret, code: code }.to_json

      response = http.request(request)
      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.error("RedmineGithub OAuth token exchange error: #{e.message}")
      nil
    end

    def fetch_github_user(access_token)
      GithubApi::Rest::Repos.new(access_token).current_user
    rescue GithubApi::Rest::Error => e
      Rails.logger.error("RedmineGithub OAuth user fetch error: #{e.message}")
      nil
    end
  end
end
