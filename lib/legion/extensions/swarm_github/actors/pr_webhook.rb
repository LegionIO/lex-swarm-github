# frozen_string_literal: true

require 'legion/extensions/actors/subscription'

module Legion
  module Extensions
    module SwarmGithub
      module Actor
        class PrWebhook < Legion::Extensions::Actors::Subscription
          def runner_class
            Legion::Extensions::SwarmGithub::Runners::PrPipeline
          end

          def runner_function
            'run_review_pipeline_from_webhook'
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end
        end
      end
    end
  end
end
