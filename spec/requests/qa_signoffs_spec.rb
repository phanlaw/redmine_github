# frozen_string_literal: true

require File.expand_path('../rails_helper', __dir__)

RSpec.describe 'QaSignoffs', type: :request do
  let(:project) { create(:project, :with_redmine_github) }
  let(:admin)   { create(:admin_user) }
  let(:version) { create(:version, project: project, effective_date: Date.tomorrow) }

  def signoff_create_path
    "/projects/#{project.identifier}/versions/#{version.id}/qa_signoffs"
  end

  def signoff_approve_path
    "/projects/#{project.identifier}/versions/#{version.id}/qa_signoffs/approve"
  end

  def signoff_reject_path
    "/projects/#{project.identifier}/versions/#{version.id}/qa_signoffs/reject"
  end

  before { login_as(admin) }

  describe 'POST create' do
    it 'creates a QaSignoff with pending status and redirects' do
      expect {
        post signoff_create_path
      }.to change(QaSignoff, :count).by(1)

      expect(response).to have_http_status(:found)
      signoff = QaSignoff.last
      expect(signoff.version_id).to eq version.id
      expect(signoff.status).to eq 'pending'
    end

    it 'is idempotent — second create reuses existing record' do
      post signoff_create_path
      expect {
        post signoff_create_path
      }.not_to change(QaSignoff, :count)
      expect(response).to have_http_status(:found)
    end
  end

  describe 'POST approve' do
    before do
      signoff = QaSignoff.for_version(version)
      signoff.assign_attributes(status: 'pending')
      signoff.save!
    end

    it 'approves the signoff and redirects' do
      post signoff_approve_path, params: { notes: 'Looks good' }

      expect(response).to have_http_status(:found)
      signoff = QaSignoff.for_version(version)
      expect(signoff.status).to eq 'approved'
      expect(signoff.user_id).to eq admin.id
      expect(signoff.notes).to eq 'Looks good'
      expect(signoff.signed_off_at).not_to be_nil
    end

    it 'marks the version as release-ready' do
      post signoff_approve_path
      expect(QaSignoff.release_ready?(version)).to be true
    end
  end

  describe 'POST reject' do
    before do
      signoff = QaSignoff.for_version(version)
      signoff.assign_attributes(status: 'pending')
      signoff.save!
    end

    it 'rejects the signoff with notes and redirects' do
      post signoff_reject_path, params: { notes: 'Needs more testing' }

      expect(response).to have_http_status(:found)
      signoff = QaSignoff.for_version(version)
      expect(signoff.status).to eq 'rejected'
      expect(signoff.user_id).to eq admin.id
      expect(signoff.notes).to eq 'Needs more testing'
    end

    it 'does not mark the version as release-ready' do
      post signoff_reject_path
      expect(QaSignoff.release_ready?(version)).to be false
    end
  end

  describe 'authorization' do
    it 'requires login — redirects anonymous user to sign-in' do
      # Use a fresh session without login
      new_session = ActionDispatch::Integration::Session.new(Rails.application)
      new_session.post signoff_create_path
      expect(new_session.response).to have_http_status(:found)
      expect(new_session.response.location).to include('/login')
    end
  end
end
