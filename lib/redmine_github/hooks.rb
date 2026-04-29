# frozen_string_literal: true

module RedmineGithub
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_index_bottom, partial: 'hooks/redmine_github/view_issues_index_bottom'
    render_on :view_issues_show_description_bottom, partial: 'hooks/redmine_github/view_issues_show_description_bottom'
    render_on :view_versions_show_bottom, partial: 'hooks/redmine_github/view_versions_show_bottom'
  end
end
