# frozen_string_literal: true

module RedmineGithub
  class IssueTestResultsController < ApplicationController
    before_action :require_login
    before_action :find_issue
    before_action :authorize_qa

    def update
      @result = IssueTestResult.for_issue(@issue)
      case params[:result]
      when 'pass'
        @result.pass!(User.current, notes: params[:notes])
      when 'fail'
        @result.fail!(User.current, notes: params[:notes])
      when 'blocked'
        @result.block!(User.current, notes: params[:notes])
      else
        redirect_to issue_path, alert: l(:error_invalid_test_result) and return
      end
      redirect_to issue_path, notice: l(:notice_test_result_saved)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to issue_path, alert: e.message
    end

    private

    def find_issue
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    end

    def authorize_qa
      deny_access unless User.current.allowed_to?(:manage_qa_signoffs, @project)
    end

    def issue_path
      issue_url(@issue)
    end
  end
end
