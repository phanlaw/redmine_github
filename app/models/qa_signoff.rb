# frozen_string_literal: true

class QaSignoff < ActiveRecord::Base
  belongs_to :version
  belongs_to :user, optional: true

  STATUSES = %w[pending approved rejected].freeze

  validates :version_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def self.for_version(version)
    find_or_initialize_by(version_id: version.id)
  end

  def self.release_ready?(version)
    where(version_id: version.id, status: 'approved').exists?
  end

  def approve!(user, notes: nil)
    assign_attributes(user_id: user.id, status: 'approved',
                      notes: notes, signed_off_at: Time.current)
    save!
  end

  def reject!(user, notes: nil)
    assign_attributes(user_id: user.id, status: 'rejected',
                      notes: notes, signed_off_at: Time.current)
    save!
  end

  def pending?  = status == 'pending'
  def approved? = status == 'approved'
  def rejected? = status == 'rejected'
end
