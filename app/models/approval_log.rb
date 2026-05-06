class ApprovalLog < ApplicationRecord
  belongs_to :version
  belongs_to :user

  enum action: { approve: 'approve', reject: 'reject' }

  validates :version_id, :user_id, :action, :role, :status, presence: true
  
  scope :for_version, ->(version) { where(version_id: version.id).order(created_at: :desc) }
  scope :recent, -> { where('created_at > ?', 30.days.ago).order(created_at: :desc) }
end
