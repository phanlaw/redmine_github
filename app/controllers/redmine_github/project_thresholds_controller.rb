# frozen_string_literal: true

module RedmineGithub
  class ProjectThresholdsController < ApplicationController
    before_action :find_project
    before_action :authorize_admin
    before_action :load_threshold, only: [:edit, :update]

    def edit
      @threshold = ProjectThreshold.for_project(@project)
    end

    def update
      @threshold = ProjectThreshold.for_project(@project)
      if @threshold.update(threshold_params)
        redirect_to edit_project_threshold_path(@project), notice: 'Thresholds updated successfully.'
      else
        render :edit
      end
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def authorize_admin
      render_403 unless User.current.admin? || @project.users.manager.include?(User.current)
    end

    def load_threshold
      @threshold = ProjectThreshold.for_project(@project)
    end

    def threshold_params
      params.require(:project_threshold).permit(
        :completion_ok, :completion_warning,
        :bug_rate_ok, :bug_rate_warning,
        :delay_rate_ok, :delay_rate_warning,
        :cycle_time_baseline_days
      )
    end
  end
end
