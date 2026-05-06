# frozen_string_literal: true

require 'test_helper'

module RedmineGithub
  class ApprovalWorkflowTest < ActiveSupport::TestCase
    def setup
      @project = create_project
      @version = create_version(@project)
      @user_admin = create_user_with_role(:admin)
      @user_qa = create_user_with_role(:qa_tester)
      @user_pm = create_user_with_role(:project_manager)
    end

    def test_initialize_creates_default_approval_records
      workflow = ApprovalWorkflow.new(@version)
      assert_not_nil ReleaseApproval.find_by(version_id: @version.id, role: 'qa')
      assert_not_nil ReleaseApproval.find_by(version_id: @version.id, role: 'pm')
    end

    def test_approve_as_qa_success
      workflow = ApprovalWorkflow.new(@version)
      workflow.approve_as_qa(@user_qa, 'Tests passed')

      approval = ReleaseApproval.find_by(version_id: @version.id, role: 'qa')
      assert_equal 'approved', approval.status
      assert_equal @user_qa.id, approval.user_id
    end

    def test_approve_as_qa_unauthorized
      workflow = ApprovalWorkflow.new(@version)
      assert_raises(StandardError) do
        workflow.approve_as_qa(@user_pm, 'Should fail')
      end
    end

    def test_approve_as_pm_requires_qa_approval
      workflow = ApprovalWorkflow.new(@version)
      assert_raises(StandardError) do
        workflow.approve_as_pm(@user_pm, 'Not ready yet')
      end
    end

    def test_approval_chain_complete
      workflow = ApprovalWorkflow.new(@version)

      workflow.approve_as_qa(@user_qa, 'QA passed')
      assert_not ApprovalWorkflow.new(@version).call[:chain_complete]

      workflow.approve_as_pm(@user_pm, 'Ready for production')
      assert ApprovalWorkflow.new(@version).call[:chain_complete]
    end

    def test_reject_qa_blocks_pm_approval
      workflow = ApprovalWorkflow.new(@version)
      workflow.reject_as_qa(@user_qa, 'Tests failed')

      assert_raises(StandardError) do
        workflow.approve_as_pm(@user_pm, 'Should fail')
      end
    end

    def test_approval_log_created_on_approve
      workflow = ApprovalWorkflow.new(@version)
      workflow.approve_as_qa(@user_qa, 'Tests passed')

      logs = ApprovalLog.where(version_id: @version.id, role: 'qa', action: 'approve')
      assert_equal 1, logs.count
      assert_equal @user_qa.id, logs.first.user_id
      assert_equal 'Tests passed', logs.first.notes
    end

    def test_call_returns_workflow_state
      workflow = ApprovalWorkflow.new(@version)
      state = workflow.call

      assert_not_nil state[:qa_approval]
      assert_not_nil state[:pm_approval]
      assert_equal 'pending', state[:qa_approval].status
      assert_equal 'pending', state[:pm_approval].status
      assert_not state[:chain_complete]
    end

    private

    def create_project
      Project.create!(name: 'Test Project', identifier: "proj_#{SecureRandom.hex(4)}")
    end

    def create_version(project)
      Version.create!(
        project: project,
        name: "v#{Time.current.to_i}",
        effective_date: 7.days.from_now
      )
    end

    def create_user_with_role(role)
      user = User.create!(
        login: "user_#{SecureRandom.hex(4)}",
        mail: "user_#{SecureRandom.hex(4)}@example.com",
        password: 'password123'
      )
      user.add_role(role) if role != :admin
      user.update(admin: true) if role == :admin
      user
    end
  end
end
