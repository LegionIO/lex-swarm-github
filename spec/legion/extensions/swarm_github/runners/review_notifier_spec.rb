# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/runners/review_notifier'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::ReviewNotifier do
  let(:notifier) { Class.new { include Legion::Extensions::SwarmGithub::Runners::ReviewNotifier }.new }

  describe '#notify_review' do
    let(:review_result) do
      {
        status: 'reviewed', pr: 'org/repo#42', files_reviewed: 3,
        summary: 'Found 1 issue',
        comments: [{ file: 'lib/foo.rb', severity: 'error', message: 'Bug' }]
      }
    end

    let(:post_result) { { posted: true, review_id: 999, comments_count: 1 } }

    context 'when lex-slack is available' do
      let(:slack_client) { double('Slack::Client') }

      before do
        stub_const('Legion::Extensions::Slack::Client', Class.new)
        allow(Legion::Extensions::Slack::Client).to receive(:new).and_return(slack_client)
      end

      it 'posts a summary to the configured channel' do
        expect(slack_client).to receive(:post_message) do |args|
          expect(args[:channel]).to eq('#code-review')
          expect(args[:text]).to include('org/repo#42')
          expect(args[:text]).to include('3 file')
          { ok: true, ts: '123.456' }
        end

        result = notifier.notify_review(
          channel: '#code-review', pull_ref: 'org/repo#42',
          review: review_result, post_result: post_result
        )
        expect(result[:notified]).to be true
      end

      it 'includes comment count in message' do
        expect(slack_client).to receive(:post_message) do |args|
          expect(args[:text]).to include('1 comment')
          { ok: true, ts: '1' }
        end

        notifier.notify_review(
          channel: '#reviews', pull_ref: 'org/repo#42',
          review: review_result, post_result: post_result
        )
      end

      it 'sends clean message when review had no issues' do
        clean_review = review_result.merge(comments: [], summary: 'All clear')
        clean_post = post_result.merge(comments_count: 0)

        expect(slack_client).to receive(:post_message) do |args|
          expect(args[:text]).to include('No issues found')
          { ok: true, ts: '1' }
        end

        notifier.notify_review(
          channel: '#reviews', pull_ref: 'org/repo#42',
          review: clean_review, post_result: clean_post
        )
      end
    end

    context 'when instantiating Slack client' do
      let(:slack_client) { double('Slack::Client') }
      let(:slack_client_class) { Class.new }

      before do
        stub_const('Legion::Extensions::Slack::Client', slack_client_class)
        allow(slack_client_class).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:post_message).and_return({ ok: true, ts: '1' })
      end

      it 'instantiates Slack client with no arguments' do
        notifier.notify_review(
          channel: '#reviews', pull_ref: 'owner/repo#1',
          review: review_result, post_result: post_result,
          extra_kwarg: 'value'
        )
        expect(slack_client_class).to have_received(:new).with(no_args)
      end
    end

    context 'when lex-slack is not available' do
      it 'returns not_available' do
        result = notifier.notify_review(
          channel: '#reviews', pull_ref: 'org/repo#42',
          review: review_result, post_result: post_result
        )
        expect(result[:notified]).to be false
        expect(result[:reason]).to eq('lex-slack not available')
      end
    end

    context 'when review was not posted' do
      let(:failed_post) { { posted: false, reason: 'lex-github not available' } }

      it 'skips notification' do
        result = notifier.notify_review(
          channel: '#reviews', pull_ref: 'org/repo#42',
          review: review_result, post_result: failed_post
        )
        expect(result[:notified]).to be false
        expect(result[:reason]).to eq('review not posted')
      end
    end
  end
end
