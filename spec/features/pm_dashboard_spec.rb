# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.feature 'PM Dashboard', type: :feature do
  let(:admin) { create(:admin_user) }
  let(:project) { create(:project, :with_redmine_github) }
  let(:sprint) { create(:version, project: project, effective_date: Date.today + 30) }

  before { login_as(admin) }

  context 'when project has no versions' do
    it 'shows no data message' do
      visit project_pm_dashboard_path(project)
      expect(page).to have_css '.nodata'
    end
  end

  context 'when sprint has open incomplete issues' do
    let(:open_status) { create(:issue_status, is_closed: false) }
    let(:high_priority) { create(:issue_priority, name: 'High') }

    before do
      create_list(:issue, 5, project: project, status: open_status,
                  priority: high_priority, fixed_version: sprint)
    end

    it 'shows release blockers panel' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)
      expect(page).to have_css '.pm-release-blockers'
      expect(page).to have_text 'Release blocked'
    end

    it 'shows sprint metrics table' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)
      expect(page).to have_css 'table.list'
      expect(page).to have_text 'Completion'
    end
  end

  context 'with a healthy sprint ready for approval' do
    let(:closed_status) { create(:issue_status, is_closed: true) }

    before do
      create_list(:issue, 10, project: project, status: closed_status, fixed_version: sprint).each do |issue|
        IssueTestResult.create!(issue: issue, result: 'pass', tester: admin)
      end
      ReleaseApproval.create!(version: sprint, role: 'QA', status: 'pending', user: admin)
      ReleaseApproval.create!(version: sprint, role: 'PM', status: 'pending', user: admin)
    end

    it 'shows release blockers panel when approvals are pending' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)
      expect(page).to have_css '.pm-release-blockers'
      expect(page).to have_text 'QA sign-off required'
    end

    it 'shows sprint metrics with passing rates' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)
      expect(page).to have_text '10 / 10'
      expect(page).to have_text '100.0%'
    end

    it 'completes QA then PM approval and shows READY FOR PRODUCTION' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)

      # Step 1: QA approval
      click_button 'Approve'
      expect(page).to have_text 'QA approval recorded'
      expect(page).to have_css '.pm-release-blockers'

      # Step 2: PM approval
      click_button 'Approve Release'
      expect(page).to have_text 'PM approval recorded'

      # Step 3: Fully approved
      expect(page).to have_css '.pm-go'
      expect(page).to have_text 'Ready for Production'
    end

    it 'shows RISKY banner and records QA rejection' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)

      click_button 'Reject'
      expect(page).to have_text 'QA approval rejected'
      expect(page).to have_css '.pm-release-rejected'
    end
  end

  context 'drill-down pages' do
    let(:closed_status) { create(:issue_status, is_closed: true) }
    let!(:closed_issue) { create(:issue, subject: 'Closed task', project: project, status: closed_status, fixed_version: sprint) }

    it 'shows closed issues drill-down' do
      visit project_pm_dashboard_closed_issues_path(project, sprint_id: sprint.id)
      expect(page).to have_text 'Closed Issues'
      expect(page).to have_text 'Closed task'
    end

    it 'shows blockers drill-down' do
      visit project_pm_dashboard_blockers_path(project, sprint_id: sprint.id)
      expect(page).to have_text 'Blockers'
    end

    it 'shows delayed tasks drill-down' do
      visit project_pm_dashboard_delayed_tasks_path(project, sprint_id: sprint.id)
      expect(page).to have_text 'Delayed Tasks'
    end

    it 'shows failed tests drill-down' do
      visit project_pm_dashboard_failed_tests_path(project, sprint_id: sprint.id)
      expect(page).to have_text 'Failed Tests'
    end
  end

  context 'audit trail' do
    it 'renders approval log entries in the timeline' do
      create(:approval_log, version: sprint, user: admin,
             action: 'approve', role: 'QA', status: 'approved',
             notes: 'All tests pass')
      create(:approval_log, version: sprint, user: admin,
             action: 'reject', role: 'PM', status: 'rejected',
             notes: 'Needs rework')

      visit project_pm_dashboard_path(project, sprint_id: sprint.id)

      expect(page).to have_css '.pm-audit'
      expect(page).to have_text 'All tests pass'
      expect(page).to have_text 'Needs rework'
    end

    it 'does not render the audit section when there are no logs' do
      visit project_pm_dashboard_path(project, sprint_id: sprint.id)
      expect(page).not_to have_css '.pm-audit'
    end
  end
end
