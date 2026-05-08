# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe 'ProjectThresholds', type: :feature do
  let(:project) { create(:project, :with_redmine_github) }
  let(:admin)   { create(:admin_user) }

  before { login_as(admin) }

  def edit_threshold_url
    "/projects/#{project.identifier}/thresholds/edit"
  end

  describe 'GET edit' do
    it 'renders the threshold form' do
      visit edit_threshold_url
      expect(page).to have_content(project.name)
      expect(page).to have_field('project_threshold[completion_ok]')
      expect(page).to have_field('project_threshold[completion_warning]')
    end
  end

  describe 'PATCH update' do
    context 'with valid values' do
      it 'saves the thresholds and stays on the edit page with success notice' do
        visit edit_threshold_url
        fill_in 'project_threshold[completion_ok]',      with: '90'
        fill_in 'project_threshold[completion_warning]', with: '70'
        find('[type=submit]').click

        expect(page).to have_content('Thresholds updated successfully')
        threshold = ProjectThreshold.for_project(project)
        expect(threshold.completion_ok.to_f).to be_within(0.01).of(90.0)
        expect(threshold.completion_warning.to_f).to be_within(0.01).of(70.0)
      end
    end

    context 'with invalid values (ok < warning)' do
      it 'shows validation errors and does not save' do
        visit edit_threshold_url
        fill_in 'project_threshold[completion_ok]',      with: '50'
        fill_in 'project_threshold[completion_warning]', with: '80'
        find('[type=submit]').click

        expect(page).to have_css('#error_explanation')
        threshold = ProjectThreshold.for_project(project)
        expect(threshold.completion_ok.to_f).not_to eq 50.0
      end
    end
  end
end
