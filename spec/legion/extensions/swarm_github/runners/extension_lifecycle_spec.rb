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
        allow(runner).to receive(:pr_reviewer_available?).and_return(false)
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
        allow(runner).to receive(:pr_reviewer_available?).and_return(false)
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

    describe 'adversarial PR review' do
      let(:mod) { described_class }

      before do
        allow(mod).to receive(:github_config).and_return(
          enabled: true, target_repo: 'Test/repo', target_branch: 'main',
          auto_merge: false, pr_labels: [], branch_prefix: 'feature/auto-gen'
        )
        allow(mod).to receive(:create_lifecycle_branch).and_return({ success: true })
        allow(mod).to receive(:commit_generated_files).and_return({ success: true })
        allow(mod).to receive(:open_pull_request).and_return({ success: true, pull_number: 1, html_url: 'url' })
        allow(mod).to receive(:label_pull_request).and_return({ success: true })
        allow(mod).to receive(:run_adversarial_review).and_return({ success: true, consensus: :approve, k: 3 })
        allow(mod).to receive(:handle_auto_merge)
      end

      it 'passes review_k through to adversarial review' do
        mod.run_lifecycle(generation: generation, review: review, review_k: 3)
        expect(mod).to have_received(:run_adversarial_review).with(hash_including(k: 3))
      end

      it 'defaults review_k to 1' do
        mod.run_lifecycle(generation: generation, review: review)
        expect(mod).to have_received(:run_adversarial_review).with(hash_including(k: 1))
      end

      it 'includes review consensus in result' do
        result = mod.run_lifecycle(generation: generation, review: review, review_k: 3)
        expect(result[:review_consensus]).to eq(:approve)
        expect(result[:review_k]).to eq(3)
      end
    end

    describe 'multi-provider adversarial review' do
      let(:mod) { described_class }

      before do
        allow(mod).to receive(:github_config).and_return(
          enabled: true, target_repo: 'Test/repo', target_branch: 'main',
          auto_merge: false, pr_labels: [], branch_prefix: 'feature/auto-gen'
        )
        allow(mod).to receive(:create_lifecycle_branch).and_return({ success: true })
        allow(mod).to receive(:commit_generated_files).and_return({ success: true })
        allow(mod).to receive(:open_pull_request).and_return({ success: true, pull_number: 1, html_url: 'url' })
        allow(mod).to receive(:label_pull_request).and_return({ success: true })
        allow(mod).to receive(:handle_auto_merge)
      end

      it 'forwards review_models to adversarial review' do
        allow(mod).to receive(:run_adversarial_review).and_return({ success: true, consensus: :approve, k: 2 })
        models = [{ provider: :bedrock, model: 'claude' }]
        mod.run_lifecycle(generation: generation, review: review, review_k: 2, review_models: models)
        expect(mod).to have_received(:run_adversarial_review).with(hash_including(models: models))
      end

      it 'uses default_review_models when review_models is nil' do
        allow(mod).to receive(:run_adversarial_review).and_return({ success: true, consensus: :approve, k: 1 })
        allow(mod).to receive(:default_review_models).and_return([])
        mod.run_lifecycle(generation: generation, review: review)
        expect(mod).to have_received(:default_review_models)
      end
    end

    describe '#build_model_assignments' do
      let(:mod) { described_class }

      it 'returns all nils when models is nil' do
        result = mod.send(:build_model_assignments, 3, nil)
        expect(result).to eq([nil, nil, nil])
      end

      it 'returns all nils when models is empty' do
        result = mod.send(:build_model_assignments, 2, [])
        expect(result).to eq([nil, nil])
      end

      it 'uses each available model at most once, then fills remaining slots with nil' do
        allow(mod).to receive(:provider_available?).and_return(true)
        models = [{ provider: :bedrock, model: 'a' }, { provider: :openai, model: 'b' }]
        result = mod.send(:build_model_assignments, 3, models)
        expect(result).to eq([{ provider: :bedrock, model: 'a' }, { provider: :openai, model: 'b' }, nil])
      end

      it 'skips unavailable providers and falls back to nil assignments' do
        allow(mod).to receive(:provider_available?).and_return(false)
        models = [{ provider: :unavailable, model: 'x' }]
        result = mod.send(:build_model_assignments, 2, models)
        expect(result).to eq([nil, nil])
      end

      it 'returns all nils and warns when models is a String' do
        expect(mod).to receive(:log).at_least(:once).and_return(double(warn: nil))
        result = mod.send(:build_model_assignments, 2, 'not-an-array')
        expect(result).to eq([nil, nil])
      end

      it 'returns all nils and warns when models is a Hash' do
        expect(mod).to receive(:log).at_least(:once).and_return(double(warn: nil))
        result = mod.send(:build_model_assignments, 2, { provider: :bedrock, model: 'claude' })
        expect(result).to eq([nil, nil])
      end

      it 'returns all nils and warns when models is an Integer' do
        expect(mod).to receive(:log).at_least(:once).and_return(double(warn: nil))
        result = mod.send(:build_model_assignments, 2, 42)
        expect(result).to eq([nil, nil])
      end

      it 'skips specs with a non-symbolizable provider value and warns' do
        logger = double(warn: nil)
        allow(mod).to receive(:log).and_return(logger)
        models = [{ provider: [1, 2], model: 'x' }, { provider: :openai, model: 'y' }]
        allow(mod).to receive(:provider_available?).with(:openai).and_return(true)
        result = mod.send(:build_model_assignments, 2, models)
        expect(logger).to have_received(:warn).with(/cannot be symbolized/)
        expect(result).to eq([{ provider: :openai, model: 'y' }, nil])
      end
    end

    describe '#provider_available?' do
      let(:mod) { described_class }

      it 'returns false when Legion::Settings is not defined' do
        hide_const('Legion::Settings') if defined?(Legion::Settings)
        expect(mod.send(:provider_available?, :bedrock)).to be false
      end
    end

    describe '#default_review_models' do
      let(:mod) { described_class }

      it 'returns empty array when Legion::Settings is not defined' do
        hide_const('Legion::Settings') if defined?(Legion::Settings)
        expect(mod.send(:default_review_models)).to eq([])
      end
    end
  end
end
