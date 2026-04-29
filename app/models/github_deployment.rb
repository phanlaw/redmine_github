# frozen_string_literal: true

class GithubDeployment < ActiveRecord::Base
  belongs_to :issue

  TERMINAL_STATES = %w[success failure error inactive].freeze

  scope :for_issue,       ->(issue) { where(issue_id: issue.id) }
  scope :production,      -> { where(environment: 'production') }
  scope :staging,         -> { where(environment: 'staging') }
  scope :by_environment,  ->(env) { where(environment: env) }
  scope :recent,          -> { order(deployed_at: :desc, id: :desc) }

  def terminal?
    TERMINAL_STATES.include?(state)
  end

  def success?
    state == 'success'
  end

  def failure?
    %w[failure error].include?(state)
  end
end
