# frozen_string_literal: true

require 'spec_helper'

# Stub base class for actor
unless defined?(Legion::Extensions::Actors::Subscription)
  module Legion
    module Extensions
      module Actors
        class Subscription
          def initialize(**); end
        end
      end
    end
  end
  $LOADED_FEATURES << 'legion/extensions/actors/subscription'
end

require 'legion/extensions/swarm_github/actors/pr_webhook'

RSpec.describe Legion::Extensions::SwarmGithub::Actor::PrWebhook do
  let(:actor) { described_class.allocate }

  it 'defines runner_class as PrPipeline' do
    expect(actor.runner_class).to eq(Legion::Extensions::SwarmGithub::Runners::PrPipeline)
  end

  it 'defines runner_function as run_review_pipeline_from_webhook' do
    expect(actor.runner_function).to eq('run_review_pipeline_from_webhook')
  end

  it 'does not check subtasks' do
    expect(actor.check_subtask?).to be false
  end

  it 'does not generate tasks' do
    expect(actor.generate_task?).to be false
  end
end
