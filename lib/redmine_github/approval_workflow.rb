# frozen_string_literal: true

module RedmineGithub
  # Manages approval workflow for release promotion.
  # Enforces: QA sign-off required, then PM sign-off.
  class ApprovalWorkflow
    def initialize(version)
      @version = version
    end

    def call
      {
        qa_approval: qa_approval,
        pm_approval: pm_approval,
        chain_complete: chain_complete?,
        can_approve: can_approve,
        can_reject: can_reject
      }
    end

    def qa_approval
      ReleaseApproval.find_or_create_by(version_id: @version.id, role: 'QA')
    end

    def pm_approval
      ReleaseApproval.find_or_create_by(version_id: @version.id, role: 'PM')
    end

    def chain_complete?
      qa_approval.approved? && pm_approval.approved?
    end

    def qa_can_approve?(user)
      user.has_role?(:qa_tester) || user.admin?
    end

    def pm_can_approve?(user)
      user.admin? || @version.project.users.manager.include?(user)
    end

    def can_approve
      {
        qa: qa_approval.pending?,
        pm: pm_approval.pending? && qa_approval.approved?
      }
    end

    def can_reject
      {
        qa: qa_approval.pending?,
        pm: pm_approval.pending? && qa_approval.approved?
      }
    end

    def approve_as_qa(user, notes = nil)
      raise "User not authorized for QA approval" unless qa_can_approve?(user)
      raise "QA approval not pending" unless qa_approval.pending?

      qa_approval.approve(notes)
    end

    def approve_as_pm(user, notes = nil)
      raise "User not authorized for PM approval" unless pm_can_approve?(user)
      raise "QA approval required before PM approval" unless qa_approval.approved?
      raise "PM approval not pending" unless pm_approval.pending?

      pm_approval.approve(notes)
    end

    def reject_as_qa(user, notes = nil)
      raise "User not authorized for QA approval" unless qa_can_approve?(user)
      raise "QA approval not pending" unless qa_approval.pending?

      qa_approval.reject(notes)
    end

    def reject_as_pm(user, notes = nil)
      raise "User not authorized for PM approval" unless pm_can_approve?(user)
      raise "QA approval required before PM approval" unless qa_approval.approved?
      raise "PM approval not pending" unless pm_approval.pending?

      pm_approval.reject(notes)
    end
  end
end
