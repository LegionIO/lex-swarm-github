# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Helpers
        module MeshIntegration
          AGENT_ID = 'swarm-github-code-reviewer'
          CAPABILITIES = %i[code_review pr_review].freeze

          module_function

          def register_reviewer
            return { skipped: true, reason: 'lex-mesh not available' } unless mesh_available?

            Legion::Extensions::Mesh::Client.new.register(
              agent_id:     AGENT_ID,
              capabilities: CAPABILITIES,
              endpoint:     'local'
            )
          end

          def record_review_start(charter_id:, owner:, repo:, pull_number:)
            return unless workspace_available?

            Legion::Extensions::Swarm::Client.new.workspace_put(
              charter_id: charter_id,
              key:        "review:#{owner}/#{repo}##{pull_number}",
              value:      { status: 'in_progress', started_at: Time.now.utc.to_s },
              author:     AGENT_ID
            )
          end

          def record_review_complete(charter_id:, owner:, repo:, pull_number:, result:)
            return unless workspace_available?

            Legion::Extensions::Swarm::Client.new.workspace_put(
              charter_id: charter_id,
              key:        "review:#{owner}/#{repo}##{pull_number}",
              value:      {
                status:         result[:review]&.dig(:status) || 'unknown',
                posted:         result[:post]&.dig(:posted) || false,
                comments_count: result[:post]&.dig(:comments_count) || 0,
                completed_at:   Time.now.utc.to_s
              },
              author:     AGENT_ID
            )
          end

          def mesh_available?
            defined?(Legion::Extensions::Mesh::Client)
          end

          def workspace_available?
            defined?(Legion::Extensions::Swarm::Client)
          end
        end
      end
    end
  end
end
