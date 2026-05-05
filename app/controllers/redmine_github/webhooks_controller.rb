# frozen_string_literal: true

module RedmineGithub
  class WebhooksController < ActionController::Base
    # verifying request by X-Hub-Signature-256 header
    skip_forgery_protection if Redmine::VERSION::MAJOR >= 5

    before_action :set_repository, :verify_signature

    def dispatch_event
      # Deduplicate: skip if this delivery ID already processed
      delivery_id = request.headers['x-github-delivery'].to_s
      event = request.headers['x-github-event']
      
      if WebhookDelivery.already_processed?(delivery_id)
        return head :ok
      end

      case event
      when 'pull_request', 'pull_request_review', 'push', 'status'
        WebhookDelivery.record_delivery(delivery_id, @repository, event)
        PullRequestHandler.handle(@repository, event, params)
        head :ok
      when 'workflow_run'
        WebhookDelivery.record_delivery(delivery_id, @repository, event)
        WorkflowRunHandler.handle(@repository, params.to_unsafe_h)
        head :ok
      when 'deployment_status'
        WebhookDelivery.record_delivery(delivery_id, @repository, event)
        DeploymentStatusHandler.handle(@repository, params.to_unsafe_h)
        head :ok
      when 'release'
        WebhookDelivery.record_delivery(delivery_id, @repository, event)
        ReleaseHandler.new(@repository, params.to_unsafe_h).handle
        head :ok
      else
        # ignore
        head :ok
      end
    end

    private

    def set_repository
      @repository = Repository::Github.find(params[:repository_id])
    end

    def verify_signature
      request.body.rewind
      signature = 'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), @repository.webhook_secret, request.body.read)
      head :bad_request unless Rack::Utils.secure_compare(signature, request.headers['x-hub-signature-256'])
    end
  end
end
