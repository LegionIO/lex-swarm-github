# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Helpers
        module Pipeline
          # GitHub swarm state machine (spec: swarm-implementation-spec.md)
          STATES = %i[received found fixing validating approved pr_open rejected stale].freeze
          LABELS = STATES.map { |s| :"swarm:#{s}" }.freeze

          # Agent roles in the GitHub pipeline
          PIPELINE_ROLES = %i[finder fixer validator pr_swarm].freeze

          # Validation
          ADVERSARIAL_REVIEW_K = 3 # number of independent validators
          MAX_FIX_ATTEMPTS     = 3
          STALE_TIMEOUT        = 86_400 # 24 hours

          module_function

          def valid_state?(state)
            STATES.include?(state)
          end

          def label_for_state(state)
            "swarm:#{state}"
          end

          def next_state(current)
            {
              received:   :found,
              found:      :fixing,
              fixing:     :validating,
              validating: :approved,
              approved:   :pr_open
            }[current]
          end
        end
      end
    end
  end
end
