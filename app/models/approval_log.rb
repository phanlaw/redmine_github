class ApprovalLog < ApplicationRecord
  belongs_to :version
  belongs_to :user

  ACTIONS = %w[approve reject].freeze

  validates :version_id, :user_id, :action, :role, :status, presence: true
  validates :action, inclusion: { in: ACTIONS }
  
  scope :for_version, ->(version) { where(version_id: version.id).order(created_at: :desc) }
  scope :recent, -> { where('created_at > ?', 30.days.ago).order(created_at: :desc) }
end
