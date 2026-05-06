# frozen_string_literal: true

module RedmineGithub
  # Service to compute audit trail for sprint approval workflow.
  # Shows timeline of approval/rejection events with who, when, and notes.
  class AuditTrailService
    def initialize(version)
      @version = version
    end

    def call
      {
        approval_history: approval_history,
        recent_approvals: recent_approvals(5),
        timeline: build_timeline
      }
    end

    def approval_history
      ApprovalLog.where(version_id: @version.id)
                  .order(created_at: :desc)
                  .includes(:user)
    end

    def recent_approvals(limit = 5)
      approval_history.limit(limit).reverse
    end

    def build_timeline
      history = approval_history
      timeline = []

      history.each do |log|
        timeline << {
          timestamp: log.created_at,
          user: log.user&.name || 'System',
          role: log.role.titleize,
          action: log.action.titleize,
          notes: log.notes,
          status: log.action == 'approve' ? 'success' : 'failure'
        }
      end

      timeline
    end
  end
end
