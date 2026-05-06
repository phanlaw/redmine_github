# frozen_string_literal: true

Redmine::Plugin.register :redmine_github do
  name 'Redmine Github plugin'
  author 'Agileware Inc.'
  description 'Redmine plugin for connecting to Github repositories'
  version '0.2.0'
  author_url 'https://agileware.jp/'

  settings default: {
             'webhook_use_hostname'       => 0,
             'github_oauth_client_id'     => '',
             'github_oauth_client_secret' => '',
             'commit_issue_prefix'        => 'RM'
           },
           partial: 'settings/redmine_github_settings'

  project_module :redmine_github do
    permission :view_github_metrics, { 'redmine_github/github_metrics' => [:index] }, read: true
    permission :view_pm_dashboard,   { 'redmine_github/pm_dashboard'   => [:index, :failed_tests] }, read: true
    permission :manage_qa_signoffs,
               { 'redmine_github/qa_signoffs'         => [:create, :approve, :reject],
                 'redmine_github/issue_test_results'   => [:update] }
  end

  menu :project_menu, :github_metrics,
       { controller: 'redmine_github/github_metrics', action: 'index' },
       caption:    :label_github_metrics,
       param:      :project_id,
       after:      :repository,
       html:       { class: 'icon icon-stats' }

  menu :project_menu, :pm_dashboard,
       { controller: 'redmine_github/pm_dashboard', action: 'index' },
       caption:    :label_pm_dashboard,
       param:      :project_id,
       after:      :github_metrics,
       html:       { class: 'icon icon-stats' }
end

Redmine::Scm::Base.add('Github')

Rails.application.config.after_initialize do
  require File.expand_path('../lib/redmine_github', __FILE__)
  require File.expand_path('../lib/redmine_github/hooks', __FILE__)
  require File.expand_path('../lib/redmine_github/github_api/rest/repos', __FILE__)
  require File.expand_path('../lib/redmine_github/include/changeset_patch', __FILE__)
  require File.expand_path('../lib/redmine_github/prepend/version_patch', __FILE__)
  require File.expand_path('../lib/redmine_github/sprint_pm_stats', __FILE__)
  require File.expand_path('../lib/redmine_github/qa_gate_stats', __FILE__)

  Issue.include RedmineGithub::Include::IssuePatch
  Issue.prepend RedmineGithub::Prepend::IssuePatch

  IssuesController.include RedmineGithub::Include::IssuesControllerPatch
  RepositoriesController.include RedmineGithub::Include::RepositoriesControllerPatch
  Changeset.include RedmineGithub::Include::ChangesetPatch

  ApplicationHelper.prepend RedmineGithub::Prepend::ApplicationHelperPatch
  Version.prepend RedmineGithub::Prepend::VersionPatch
end
