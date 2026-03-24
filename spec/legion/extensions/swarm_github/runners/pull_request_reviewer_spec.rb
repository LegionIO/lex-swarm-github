# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/runners/pull_request_reviewer'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::PullRequestReviewer do
  let(:reviewer) { Class.new { include Legion::Extensions::SwarmGithub::Runners::PullRequestReviewer }.new }

  describe '#review_pull_request' do
    context 'when PR has no files' do
      before do
        allow(reviewer).to receive(:fetch_pr_files).and_return([])
      end

      it 'returns skipped status' do
        result = reviewer.review_pull_request(owner: 'test', repo: 'repo', pull_number: 1)
        expect(result[:status]).to eq('skipped')
        expect(result[:reason]).to eq('no files')
      end
    end

    context 'when PR has files' do
      let(:files) do
        [{ filename: 'lib/foo.rb', patch: '+ def bar; end' }]
      end

      before do
        allow(reviewer).to receive(:fetch_pr_files).and_return(files)
        allow(reviewer).to receive(:generate_review).and_return(
          { summary: 'Looks good', comments: [] }
        )
      end

      it 'returns reviewed status with file count' do
        result = reviewer.review_pull_request(owner: 'test', repo: 'repo', pull_number: 42)
        expect(result[:status]).to eq('reviewed')
        expect(result[:files_reviewed]).to eq(1)
        expect(result[:pr]).to eq('test/repo#42')
        expect(result[:summary]).to eq('Looks good')
      end

      it 'includes comments array from review' do
        result = reviewer.review_pull_request(owner: 'test', repo: 'repo', pull_number: 42)
        expect(result[:comments]).to eq([])
      end
    end

    context 'when diff exceeds max_chars' do
      let(:large_files) do
        [
          { filename: 'a.rb', patch: 'x' * 7000 },
          { filename: 'b.rb', patch: 'y' * 7000 }
        ]
      end

      before do
        stub_const('Legion::LLM', Module.new)
        allow(reviewer).to receive(:fetch_pr_files).and_return(large_files)
        allow(Legion::LLM).to receive(:chat).and_return('{"summary":"ok","comments":[]}')
      end

      it 'calls LLM multiple times for chunked diffs' do
        reviewer.review_pull_request(owner: 'owner', repo: 'repo', pull_number: 1)
        expect(Legion::LLM).to have_received(:chat).at_least(2).times
      end
    end

    context 'when PR has multiple files with comments' do
      let(:files) do
        [
          { filename: 'lib/foo.rb', patch: '+ def bar; end' },
          { filename: 'lib/baz.rb', patch: '+ x = dangerous_call(input)' }
        ]
      end

      let(:review_result) do
        {
          summary:  'Security issue found',
          comments: [
            { file: 'lib/baz.rb', line: 1, severity: 'error', message: 'Unsafe call with user input' }
          ]
        }
      end

      before do
        allow(reviewer).to receive(:fetch_pr_files).and_return(files)
        allow(reviewer).to receive(:generate_review).and_return(review_result)
      end

      it 'returns correct file count' do
        result = reviewer.review_pull_request(owner: 'test', repo: 'repo', pull_number: 5)
        expect(result[:files_reviewed]).to eq(2)
      end

      it 'passes through comments from review' do
        result = reviewer.review_pull_request(owner: 'test', repo: 'repo', pull_number: 5)
        expect(result[:comments].size).to eq(1)
        expect(result[:comments].first[:severity]).to eq('error')
      end
    end
  end
end
