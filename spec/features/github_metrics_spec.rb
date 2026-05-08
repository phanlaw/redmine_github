# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.feature 'GitHub Metrics', type: :feature do
  let(:admin) { create(:admin_user) }
  let(:project) { create(:project, :with_redmine_github) }

  before { login_as(admin) }

  it 'loads the GitHub metrics page' do
    visit project_github_metrics_path(project)
    expect(page).to have_http_status(:ok)
  end

  it 'shows DORA metrics section' do
    visit project_github_metrics_path(project)
    expect(page).to have_text 'GitHub'
  end

  context 'with a GitHub repository and version' do
    let!(:repo) { create(:github_repository, project: project) }
    let!(:version) { create(:version, project: project) }

    it 'shows version in the metrics table' do
      visit project_github_metrics_path(project)
      expect(page).to have_text version.name
    end
  end
end
