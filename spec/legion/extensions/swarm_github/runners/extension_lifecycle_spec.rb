# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/runners/extension_lifecycle'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::ExtensionLifecycle do
  subject(:runner) { described_class }

  after { described_class.instance_variable_set(:@github_client, nil) }

  let(:generation) do
    {
      name:          'lex-foo',
      generation_id: 'gen-abc123',
      gap_id:        'gap-001',
      gap_type:      'missing_runner',
      tier:          'utility',
      file_path:     'lib/legion/extensions/foo.rb',
      spec_path:     'spec/legion/extensions/foo_spec.rb',
      code:          '# runner code',
      spec_code:     '# spec code'
    }
  end

  let(:review) { { verdict: 'approve', stages: { syntax: { passed: true }, quality: { passed: true } } } }

  describe '#run_lifecycle' do
    context 'when github is not enabled' do
      it 'returns github_not_enabled error' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result).to eq({ success: false, error: :github_not_enabled })
      end
    end

    context 'when github is enabled but target_repo is missing' do
      before do
        allow(runner).to receive(:github_config).and_return(
          { enabled: true, target_repo: nil, target_branch: 'main',
            auto_merge: false, pr_labels: [], branch_prefix: 'feature/auto-generated' }
        )
      end

      it 'returns target_repo_missing error' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result).to eq({ success: false, error: :target_repo_missing })
      end
    end

    context 'when github runner is unavailable' do
      before do
        allow(runner).to receive(:github_config).and_return(
          { enabled: true, target_repo: 'org/repo', target_branch: 'main',
            auto_merge: false, pr_labels: [], branch_prefix: 'feature/auto-generated' }
        )
        allow(runner).to receive(:github_runner_available?).and_return(false)
      end

      it 'returns github_runner_unavailable on branch creation' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result).to eq({ success: false, error: :github_runner_unavailable })
      end
    end

    context 'when all pipeline steps succeed' do
      let(:github_client) { double('Github::Client') }

      before do
        runner.instance_variable_set(:@github_client, nil)
        allow(runner).to receive(:github_config).and_return(
          { enabled: true, target_repo: 'org/repo', target_branch: 'main',
            auto_merge: false, pr_labels: %w[auto-generated needs-review],
            branch_prefix: 'feature/auto-generated' }
        )
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:create_branch).and_return({ success: true })
        allow(github_client).to receive(:commit_files).and_return({ success: true })
        allow(github_client).to receive(:create_pull_request).and_return(
          { result: { 'number' => 42, 'html_url' => 'https://github.com/org/repo/pull/42' } }
        )
        allow(github_client).to receive(:add_labels).and_return({ success: true })
      end

      it 'returns success with PR details' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result[:success]).to be true
        expect(result[:pull_number]).to eq(42)
        expect(result[:html_url]).to eq('https://github.com/org/repo/pull/42')
        expect(result[:generation_id]).to eq('gen-abc123')
      end

      it 'calls create_branch' do
        runner.run_lifecycle(generation: generation, review: review)
        expect(github_client).to have_received(:create_branch)
      end

      it 'calls commit_files with file list' do
        runner.run_lifecycle(generation: generation, review: review)
        expect(github_client).to have_received(:commit_files).with(
          hash_including(files: array_including(hash_including(path: 'lib/legion/extensions/foo.rb')))
        )
      end

      it 'calls create_pull_request' do
        runner.run_lifecycle(generation: generation, review: review)
        expect(github_client).to have_received(:create_pull_request).with(
          hash_including(title: 'auto-generated: lex-foo')
        )
      end

      it 'calls add_labels' do
        runner.run_lifecycle(generation: generation, review: review)
        expect(github_client).to have_received(:add_labels).with(
          hash_including(labels: %w[auto-generated needs-review])
        )
      end
    end

    context 'when branch creation fails' do
      before do
        runner.instance_variable_set(:@github_client, nil)
        allow(runner).to receive(:github_config).and_return(
          { enabled: true, target_repo: 'org/repo', target_branch: 'main',
            auto_merge: false, pr_labels: [], branch_prefix: 'feature/auto-generated' }
        )
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(double(
                                                                                create_branch: { success: false, error: 'branch exists' }
                                                                              ))
      end

      it 'propagates the branch error' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('branch exists')
      end
    end

    context 'when auto_merge is enabled and verdict is approve' do
      let(:github_client) { double('Github::Client') }
      let(:review_approve) { { verdict: 'approve', stages: {} } }

      before do
        runner.instance_variable_set(:@github_client, nil)
        allow(runner).to receive(:github_config).and_return(
          { enabled: true, target_repo: 'org/repo', target_branch: 'main',
            auto_merge: true, pr_labels: [], branch_prefix: 'feature/auto-generated' }
        )
        stub_const('Legion::Extensions::Github::Client', Class.new)
        allow(Legion::Extensions::Github::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:create_branch).and_return({ success: true })
        allow(github_client).to receive(:commit_files).and_return({ success: true })
        allow(github_client).to receive(:create_pull_request).and_return(
          { result: { 'number' => 7, 'html_url' => 'https://github.com/org/repo/pull/7' } }
        )
        allow(github_client).to receive(:merge_pull_request).and_return({ success: true })
      end

      it 'calls merge_pull_request' do
        runner.run_lifecycle(generation: generation, review: review_approve)
        expect(github_client).to have_received(:merge_pull_request).with(
          hash_including(pull_number: 7)
        )
      end
    end

    context 'when a StandardError is raised' do
      before do
        allow(runner).to receive(:github_config).and_raise(RuntimeError, 'unexpected failure')
      end

      it 'returns success false with error message' do
        result = runner.run_lifecycle(generation: generation, review: review)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('unexpected failure')
      end
    end
  end
end
