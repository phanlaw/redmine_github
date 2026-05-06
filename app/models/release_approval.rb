class ReleaseApproval < ApplicationRecord
  belongs_to :version
  belongs_to :user

  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }
  enum role: { qa: 'QA', pm: 'PM' }

  validates :version_id, :user_id, :role, presence: true
  validates :version_id, uniqueness: { scope: :role, message: 'role can only have one approval' }

  scope :for_version, ->(version) { where(version_id: version.id) }
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def approve(notes = nil)
    update(status: 'approved', notes: notes, approved_at: Time.current)
    log_approval('approve')
  end

  def reject(notes = nil)
    update(status: 'rejected', notes: notes, approved_at: nil)
    log_approval('reject')
  end

  def qa?
    role == 'qa'
  end

  def pm?
    role == 'pm'
  end

  def pending?
    status == 'pending'
  end

  private

  def log_approval(action)
    ApprovalLog.create(
      version_id: version_id,
      user_id: user_id,
      action: action,
      role: role,
      status: status,
      notes: notes
    )
  end
end
