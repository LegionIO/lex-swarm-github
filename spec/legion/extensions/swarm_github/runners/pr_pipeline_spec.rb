# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/client'
require 'legion/extensions/swarm_github/helpers/pipeline'
require 'legion/extensions/swarm_github/helpers/mesh_integration'
require 'legion/extensions/swarm_github/runners/pull_request_reviewer'
require 'legion/extensions/swarm_github/runners/review_poster'
require 'legion/extensions/swarm_github/runners/review_notifier'
require 'legion/extensions/swarm_github/runners/pr_pipeline'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::PrPipeline do
  let(:pipeline) do
    klass = Class.new do
      include Legion::Extensions::SwarmGithub::Runners::PullRequestReviewer
      include Legion::Extensions::SwarmGithub::Runners::ReviewPoster
      include Legion::Extensions::SwarmGithub::Runners::ReviewNotifier
      include Legion::Extensions::SwarmGithub::Runners::PrPipeline
    end
    klass.new
  end

  describe '#run_review_pipeline' do
    let(:review_result) do
      { status: 'reviewed', pr: 'org/repo#1', files_reviewed: 2,
        summary: 'OK', comments: [] }
    end
    let(:post_result) { { posted: true, review_id: 1, comments_count: 0 } }
    let(:notify_result) { { notified: true } }

    before do
      allow(pipeline).to receive(:review_pull_request).and_return(review_result)
      allow(pipeline).to receive(:post_review).and_return(post_result)
      allow(pipeline).to receive(:notify_review).and_return(notify_result)
    end

    it 'calls review, post, notify in sequence' do
      expect(pipeline).to receive(:review_pull_request).ordered
      expect(pipeline).to receive(:post_review).ordered
      expect(pipeline).to receive(:notify_review).ordered

      pipeline.run_review_pipeline(owner: 'org', repo: 'repo', pull_number: 1)
    end

    it 'returns combined result' do
      result = pipeline.run_review_pipeline(owner: 'org', repo: 'repo', pull_number: 1)
      expect(result[:review][:status]).to eq('reviewed')
      expect(result[:post][:posted]).to be true
      expect(result[:notify][:notified]).to be true
    end

    it 'passes slack_channel to notify' do
      expect(pipeline).to receive(:notify_review).with(hash_including(channel: '#my-reviews'))

      pipeline.run_review_pipeline(owner: 'org', repo: 'repo', pull_number: 1,
                                   slack_channel: '#my-reviews')
    end

    it 'uses default channel when none provided' do
      expect(pipeline).to receive(:notify_review).with(hash_including(channel: '#code-reviews'))

      pipeline.run_review_pipeline(owner: 'org', repo: 'repo', pull_number: 1)
    end

    it 'skips post and notify when review is skipped' do
      allow(pipeline).to receive(:review_pull_request)
        .and_return({ status: 'skipped', reason: 'no files' })

      expect(pipeline).not_to receive(:post_review)
      expect(pipeline).not_to receive(:notify_review)

      result = pipeline.run_review_pipeline(owner: 'org', repo: 'repo', pull_number: 1)
      expect(result[:review][:status]).to eq('skipped')
      expect(result[:post]).to be_nil
      expect(result[:notify]).to be_nil
    end
  end

  describe '#run_review_pipeline with issue bridge' do
    let(:client) { Legion::Extensions::SwarmGithub::Client.new }

    before do
      client.ingest_issue(repo: 'owner/repo', issue_number: 5, title: 'Fix bug')
      client.claim_issue(key: 'owner/repo#5')
      client.start_fix(key: 'owner/repo#5')
      allow(client).to receive(:review_pull_request).and_return(
        { status: 'reviewed', files_reviewed: 1, summary: 'OK', comments: [] }
      )
      allow(client).to receive(:post_review).and_return({ posted: true, review_id: 1, comments_count: 0 })
      allow(client).to receive(:notify_review).and_return({ notified: false, reason: 'lex-slack not available' })
    end

    context 'when PR is linked to a tracked issue' do
      it 'records review as validation on the linked issue' do
        client.run_review_pipeline(owner: 'owner', repo: 'repo', pull_number: 1, issue_number: 5)
        issue = client.get_issue(key: 'owner/repo#5')[:issue]
        expect(issue[:validations]).not_to be_empty
      end
    end
  end

  describe '#run_review_pipeline_from_webhook' do
    let(:review_result) do
      { status: 'reviewed', pr: 'LegionIO/core#7', files_reviewed: 2,
        summary: 'OK', comments: [] }
    end

    before do
      allow(pipeline).to receive(:review_pull_request).and_return(review_result)
      allow(pipeline).to receive(:post_review).and_return({ posted: true, review_id: 1, comments_count: 0 })
      allow(pipeline).to receive(:notify_review).and_return({ notified: true })
    end

    it 'extracts owner, repo, pull_number from pull_request event' do
      payload = {
        'action'       => 'opened',
        'pull_request' => { 'number' => 7 },
        'repository'   => { 'full_name' => 'LegionIO/core' }
      }

      expect(pipeline).to receive(:review_pull_request)
        .with(hash_including(owner: 'LegionIO', repo: 'core', pull_number: 7))
        .and_return(review_result)

      pipeline.run_review_pipeline_from_webhook(payload: payload)
    end

    it 'ignores non-reviewable actions' do
      payload = { 'action' => 'closed', 'pull_request' => { 'number' => 1 },
                  'repository' => { 'full_name' => 'a/b' } }

      result = pipeline.run_review_pipeline_from_webhook(payload: payload)
      expect(result[:skipped]).to be true
      expect(result[:reason]).to eq('action not reviewable')
    end
  end

  describe '#handle_mesh_review_request' do
    let(:review_result) do
      { review: { status: 'reviewed' }, post: { posted: true, comments_count: 2 }, notify: { notified: true } }
    end

    before do
      allow(pipeline).to receive(:run_review_pipeline).and_return(review_result)
      allow(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_start)
      allow(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_complete)
    end

    it 'returns success: false when owner is missing' do
      result = pipeline.handle_mesh_review_request(payload: { repo: 'myrepo', pull_number: 1 })
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:missing_params)
    end

    it 'returns success: false when repo is missing' do
      result = pipeline.handle_mesh_review_request(payload: { owner: 'org', pull_number: 1 })
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:missing_params)
    end

    it 'returns success: false when pull_number is missing' do
      result = pipeline.handle_mesh_review_request(payload: { owner: 'org', repo: 'myrepo' })
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:missing_params)
    end

    it 'calls run_review_pipeline with extracted params' do
      expect(pipeline).to receive(:run_review_pipeline)
        .with(hash_including(owner: 'org', repo: 'myrepo', pull_number: 42))
        .and_return(review_result)

      pipeline.handle_mesh_review_request(payload: { owner: 'org', repo: 'myrepo', pull_number: 42 })
    end

    it 'merges success: true into pipeline result' do
      result = pipeline.handle_mesh_review_request(
        payload: { owner: 'org', repo: 'myrepo', pull_number: 42 }
      )
      expect(result[:success]).to be true
      expect(result[:review][:status]).to eq('reviewed')
    end

    it 'accepts string-keyed payload' do
      expect(pipeline).to receive(:run_review_pipeline)
        .with(hash_including(owner: 'org', repo: 'myrepo', pull_number: 5))
        .and_return(review_result)

      pipeline.handle_mesh_review_request(payload: { 'owner' => 'org', 'repo' => 'myrepo', 'pull_number' => 5 })
    end

    it 'records workspace start before pipeline runs' do
      expect(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_start).ordered
      expect(pipeline).to receive(:run_review_pipeline).ordered.and_return(review_result)

      pipeline.handle_mesh_review_request(payload: { owner: 'org', repo: 'myrepo', pull_number: 1 })
    end

    it 'records workspace complete after pipeline runs' do
      expect(pipeline).to receive(:run_review_pipeline).ordered.and_return(review_result)
      expect(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_complete).ordered

      pipeline.handle_mesh_review_request(payload: { owner: 'org', repo: 'myrepo', pull_number: 1 })
    end

    it 'uses provided charter_id for workspace calls' do
      expect(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_start)
        .with(hash_including(charter_id: 'my-charter'))

      pipeline.handle_mesh_review_request(
        payload:    { owner: 'org', repo: 'myrepo', pull_number: 1 },
        charter_id: 'my-charter'
      )
    end

    it 'generates a charter_id when none provided' do
      expect(Legion::Extensions::SwarmGithub::Helpers::MeshIntegration).to receive(:record_review_start)
        .with(hash_including(charter_id: 'mesh-review-org-myrepo-42'))

      pipeline.handle_mesh_review_request(payload: { owner: 'org', repo: 'myrepo', pull_number: 42 })
    end
  end
end
