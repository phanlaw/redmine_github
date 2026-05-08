# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe 'Webhooks', type: :request do
  let(:project)    { create(:project, :with_redmine_github) }
  # URL must match the PR payload html_url pattern so PullRequest#repository can resolve it
  let(:repository) { create(:github_repository, project: project, url: 'https://github.com/company/repo.git') }
  let(:issue)      { create(:issue, project: project) }

  def webhook_url
    "/redmine_github/#{repository.id}/webhook"
  end

  def sign(body)
    secret = repository.webhook_secret
    'sha256=' + OpenSSL::HMAC.hexdigest('sha256', secret, body)
  end

  def post_webhook(payload_hash, event:, delivery_id: SecureRandom.hex)
    body = payload_hash.to_json
    post webhook_url, params: body,
         headers: {
           'Content-Type'          => 'application/json',
           'x-github-event'        => event,
           'x-github-delivery'     => delivery_id,
           'x-hub-signature-256'   => sign(body)
         }
  end

  def pr_payload(issue_id:, action: 'opened', merged: false)
    {
      pull_request: {
        head:       { ref: "feature/@#{issue_id}" },
        html_url:   "https://github.com/company/repo/pull/1",
        title:      "Fix issue #{issue_id}",
        body:       '',
        action:     action,
        merged:     merged,
        created_at: Time.current.iso8601
      }
    }
  end

  before do
    # Stub PullRequest#sync to avoid GraphQL HTTP calls in webhook tests.
    # The GraphQL sync logic is independently tested in spec/lib/github_api/graphql_spec.rb.
    allow_any_instance_of(PullRequest).to receive(:sync).and_return(nil)

    repository
    issue
  end

  describe 'POST /redmine_github/:repository_id/webhook' do
    context 'pull_request opened' do
      it 'creates a PullRequest record and returns 200' do
        expect {
          post_webhook(pr_payload(issue_id: issue.id), event: 'pull_request')
        }.to change(PullRequest, :count).by(1)

        expect(response).to have_http_status(:ok)
        pr = PullRequest.last
        expect(pr.url).to eq 'https://github.com/company/repo/pull/1'
        expect(pr.title).to eq "Fix issue #{issue.id}"
      end
    end

    context 'pull_request merged' do
      it 'updates existing PullRequest to merged' do
        pr = create(:pull_request, issue: issue, url: 'https://github.com/company/repo/pull/1')
        # Override sync stub: simulate what a successful GitHub API response would do
        allow_any_instance_of(PullRequest).to receive(:sync) do |pr_instance|
          pr_instance.update_columns(merged_at: Time.current, mergeable_state: 'MERGED')
        end

        expect {
          post_webhook(pr_payload(issue_id: issue.id, action: 'closed', merged: true), event: 'pull_request')
        }.not_to change(PullRequest, :count)

        expect(response).to have_http_status(:ok)
        expect(pr.reload.merged_at).not_to be_nil
      end
    end

    context 'deduplication' do
      it 'ignores re-delivered events with the same delivery ID' do
        delivery_id = 'dup-delivery-001'
        post_webhook(pr_payload(issue_id: issue.id), event: 'pull_request', delivery_id: delivery_id)
        expect(PullRequest.count).to eq 1

        expect {
          post_webhook(pr_payload(issue_id: issue.id), event: 'pull_request', delivery_id: delivery_id)
        }.not_to change(PullRequest, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'unknown event type' do
      it 'returns 200 without creating any records' do
        payload = { zen: 'Keep it logically awesome.' }.to_json
        post webhook_url, params: payload,
             headers: {
               'Content-Type'        => 'application/json',
               'x-github-event'      => 'ping',
               'x-github-delivery'   => 'ping-001',
               'x-hub-signature-256' => 'sha256=' + OpenSSL::HMAC.hexdigest('sha256', repository.webhook_secret, payload)
             }

        expect(response).to have_http_status(:ok)
        expect(PullRequest.count).to eq 0
      end
    end

    context 'invalid signature' do
      it 'returns 400 Bad Request' do
        body = pr_payload(issue_id: issue.id).to_json
        post webhook_url, params: body,
             headers: {
               'Content-Type'        => 'application/json',
               'x-github-event'      => 'pull_request',
               'x-github-delivery'   => 'bad-sig-001',
               'x-hub-signature-256' => 'sha256=invalidsignature'
             }

        expect(response).to have_http_status(:bad_request)
        expect(PullRequest.count).to eq 0
      end
    end
  end
end
