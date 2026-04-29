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

scope '/projects/:project_id', module: 'redmine_github' do
  get 'github_metrics', as: 'project_github_metrics', to: 'github_metrics#index'

  scope '/versions/:version_id' do
    post 'qa_signoffs',         as: 'version_qa_signoffs',        to: 'qa_signoffs#create'
    post 'qa_signoffs/approve', as: 'version_qa_signoffs_approve', to: 'qa_signoffs#approve'
    post 'qa_signoffs/reject',  as: 'version_qa_signoffs_reject',  to: 'qa_signoffs#reject'
  end

  scope '/issues/:issue_id' do
    post 'test_result', as: 'issue_test_result', to: 'issue_test_results#update'
  end
end
