# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/runners/review_poster'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::ReviewPoster do
  let(:poster) { Class.new { include Legion::Extensions::SwarmGithub::Runners::ReviewPoster }.new }

  describe '#post_review' do
    let(:review_result) do
      {
        status: 'reviewed', pr: 'org/repo#42', files_reviewed: 3,
        summary: 'Found 1 issue',
        comments: [{ file: 'lib/foo.rb', line: 10, severity: 'error', message: 'SQL injection' }]
      }
    end

    context 'when lex-github is available' do
      let(:github_client) { double('Github::Client') }

      before do
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(github_client)
      end

      it 'posts a review to GitHub with formatted body' do
        expect(github_client).to receive(:create_review) do |args|
          expect(args[:owner]).to eq('org')
          expect(args[:repo]).to eq('repo')
          expect(args[:pull_number]).to eq(42)
          expect(args[:body]).to include('Found 1 issue')
          expect(args[:body]).to include('3 file')
          { result: { 'id' => 999 } }
        end

        result = poster.post_review(owner: 'org', repo: 'repo', pull_number: 42, review: review_result)
        expect(result[:posted]).to be true
        expect(result[:review_id]).to eq(999)
      end

      it 'converts comments to GitHub inline format' do
        expect(github_client).to receive(:create_review) do |args|
          expect(args[:comments].size).to eq(1)
          expect(args[:comments].first[:path]).to eq('lib/foo.rb')
          expect(args[:comments].first[:body]).to include('SQL injection')
          { result: { 'id' => 999 } }
        end

        poster.post_review(owner: 'org', repo: 'repo', pull_number: 42, review: review_result)
      end

      it 'handles review with no comments' do
        no_comments = review_result.merge(comments: [], summary: 'All clear')
        expect(github_client).to receive(:create_review) do |args|
          expect(args[:comments]).to eq([])
          { result: { 'id' => 1 } }
        end

        result = poster.post_review(owner: 'org', repo: 'repo', pull_number: 42, review: no_comments)
        expect(result[:posted]).to be true
      end
    end

    context 'when review has no critical or high severity comments' do
      let(:github_client) { double('Github::Client') }
      let(:review) { { status: 'reviewed', files_reviewed: 1, summary: 'Looks good', comments: [{ severity: 'info', message: 'nit' }] } }

      before do
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:create_review).and_return({ result: { 'id' => 1 } })
      end

      it 'posts with APPROVE event' do
        poster.post_review(owner: 'owner', repo: 'repo', pull_number: 1, review: review)
        expect(github_client).to have_received(:create_review).with(
          hash_including(event: 'APPROVE')
        )
      end
    end

    context 'when review has critical severity comments' do
      let(:github_client) { double('Github::Client') }
      let(:review) { { status: 'reviewed', files_reviewed: 1, summary: 'Issues found', comments: [{ severity: 'critical', message: 'bug' }] } }

      before do
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:create_review).and_return({ result: { 'id' => 2 } })
      end

      it 'posts with REQUEST_CHANGES event' do
        poster.post_review(owner: 'owner', repo: 'repo', pull_number: 1, review: review)
        expect(github_client).to have_received(:create_review).with(
          hash_including(event: 'REQUEST_CHANGES')
        )
      end
    end

    context 'when lex-github is not available' do
      it 'returns not_available error' do
        result = poster.post_review(owner: 'org', repo: 'repo', pull_number: 42, review: review_result)
        expect(result[:posted]).to be false
        expect(result[:reason]).to eq('lex-github not available')
      end
    end

    context 'when review was skipped' do
      let(:skipped) { { status: 'skipped', reason: 'no files' } }

      it 'returns skipped without posting' do
        result = poster.post_review(owner: 'org', repo: 'repo', pull_number: 1, review: skipped)
        expect(result[:posted]).to be false
        expect(result[:reason]).to eq('review was skipped')
      end
    end
  end
end
