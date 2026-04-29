# frozen_string_literal: true

namespace :redmine_github do
  post '/:repository_id/webhook', as: 'webhook', to: 'webhooks#dispatch_event'

  scope :oauth do
    get  'authorize',   as: 'oauth_authorize',   to: 'oauth#authorize'
    get  'callback',    as: 'oauth_callback',     to: 'oauth#callback'
    post 'disconnect',  as: 'oauth_disconnect',   to: 'oauth#disconnect'
  end

  get 'repos', as: 'repos', to: 'oauth#repos'
  get 'orgs',  as: 'orgs',  to: 'oauth#orgs'
end
