# frozen_string_literal: true

class DashboardAnalytic < ApplicationRecord
  self.table_name = 'dashboard_analytics'

  belongs_to :user, optional: true
  belongs_to :project

  validates :event_type, :project_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_event, ->(type) { where(event_type: type) }
  scope :by_project, ->(proj) { where(project_id: proj.id) }
  scope :since, ->(time) { where('created_at >= ?', time) }
  scope :this_week, -> { since(1.week.ago) }
  scope :this_month, -> { since(1.month.ago) }

  # Track page view
  def self.track_page_view(project, user = nil)
    create!(
      event_type: 'page_view',
      project_id: project.id,
      user_id: user&.id,
      metadata: { path: 'pm_dashboard' }
    )
  end

  # Track drill-down click
  def self.track_drill_down(project, drill_type, user = nil)
    create!(
      event_type: 'drill_down_click',
      project_id: project.id,
      user_id: user&.id,
      metadata: { drill_type: drill_type }
    )
  end

  # Track approval action
  def self.track_approval_action(project, action, role, user = nil)
    create!(
      event_type: 'approval_action',
      project_id: project.id,
      user_id: user&.id,
      metadata: { action: action, role: role }
    )
  end

  # Analytics methods
  def self.page_views_summary(project, period = :week)
    scope = by_project(project).by_event('page_view')
    scope = scope.send("this_#{period}") unless period == :all
    count
  end

  def self.drill_down_summary(project, period = :week)
    scope = by_project(project).by_event('drill_down_click')
    scope = scope.send("this_#{period}") unless period == :all
    
    results = {}
    scope.pluck(:metadata).each do |meta|
      drill_type = meta['drill_type']
      results[drill_type] = (results[drill_type] || 0) + 1
    end
    results
  end

  def self.approval_summary(project, period = :week)
    scope = by_project(project).by_event('approval_action')
    scope = scope.send("this_#{period}") unless period == :all
    
    results = { approve: 0, reject: 0 }
    scope.pluck(:metadata).each do |meta|
      action = meta['action']
      results[action.to_sym] = (results[action.to_sym] || 0) + 1
    end
    results
  end

  def self.active_users(project, period = :week)
    scope = by_project(project)
    scope = scope.send("this_#{period}") unless period == :all
    scope.distinct.pluck(:user_id).compact.count
  end

  def self.top_users(project, limit = 10, period = :week)
    scope = by_project(project)
    scope = scope.send("this_#{period}") unless period == :all
    
    scope.group(:user_id)
         .select('user_id, COUNT(*) as action_count')
         .order('action_count DESC')
         .limit(limit)
         .map { |record| { user_id: record.user_id, actions: record.action_count } }
  end
end
