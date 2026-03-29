# frozen_string_literal: true

module Legion
  module Extensions
    module Actors
      class Subscription # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

$LOADED_FEATURES << 'legion/extensions/actors/subscription'

require_relative '../../../../../lib/legion/extensions/swarm_github/runners/extension_lifecycle'
require_relative '../../../../../lib/legion/extensions/swarm_github/actors/lifecycle_subscriber'

RSpec.describe Legion::Extensions::SwarmGithub::Actor::LifecycleSubscriber do
  subject(:actor) { described_class.new }

  describe '#runner_function' do
    it { expect(actor.runner_function).to eq('action') }
  end

  describe '#check_subtask?' do
    it { expect(actor.check_subtask?).to be false }
  end

  describe '#generate_task?' do
    it { expect(actor.generate_task?).to be false }
  end

  describe '#action' do
    let(:generation) do
      { name: 'lex-foo', generation_id: 'gen-1', file_path: 'lib/foo.rb', spec_path: 'spec/foo_spec.rb' }
    end

    context 'when verdict is not approve' do
      it 'skips with :not_approved reason' do
        result = actor.action({ verdict: 'reject', generation: generation })
        expect(result[:skipped]).to be true
        expect(result[:reason]).to eq(:not_approved)
      end

      it 'handles string verdict' do
        result = actor.action({ 'verdict' => 'pending', 'generation' => {} })
        expect(result[:skipped]).to be true
        expect(result[:reason]).to eq(:not_approved)
      end
    end

    context 'when verdict is approve but github lifecycle is disabled' do
      before do
        allow(actor).to receive(:github_lifecycle_enabled?).and_return(false)
      end

      it 'skips with :github_disabled reason' do
        result = actor.action({ verdict: 'approve', generation: generation })
        expect(result[:skipped]).to be true
        expect(result[:reason]).to eq(:github_disabled)
      end
    end

    context 'when verdict is approve and github lifecycle is enabled' do
      let(:lifecycle_result) { { success: true, pull_number: 99, html_url: 'https://github.com/org/repo/pull/99' } }

      before do
        allow(actor).to receive(:github_lifecycle_enabled?).and_return(true)
        allow(Legion::Extensions::SwarmGithub::Runners::ExtensionLifecycle)
          .to receive(:run_lifecycle).and_return(lifecycle_result)
      end

      it 'calls ExtensionLifecycle.run_lifecycle' do
        actor.action({ verdict: 'approve', generation: generation })
        expect(Legion::Extensions::SwarmGithub::Runners::ExtensionLifecycle)
          .to have_received(:run_lifecycle)
      end

      it 'passes generation and review payload correctly' do
        payload = { verdict: 'approve', generation: generation, extra_key: 'value' }
        actor.action(payload)
        expect(Legion::Extensions::SwarmGithub::Runners::ExtensionLifecycle)
          .to have_received(:run_lifecycle).with(
            generation: generation,
            review:     hash_including(verdict: 'approve')
          )
      end

      it 'returns the lifecycle result' do
        result = actor.action({ verdict: 'approve', generation: generation })
        expect(result).to eq(lifecycle_result)
      end
    end

    context 'when a StandardError is raised' do
      before do
        allow(actor).to receive(:github_lifecycle_enabled?).and_return(true)
        allow(Legion::Extensions::SwarmGithub::Runners::ExtensionLifecycle)
          .to receive(:run_lifecycle).and_raise(RuntimeError, 'boom')
      end

      it 'returns success false with error message' do
        result = actor.action({ verdict: 'approve', generation: {} })
        expect(result[:success]).to be false
        expect(result[:error]).to eq('boom')
      end
    end
  end
end
