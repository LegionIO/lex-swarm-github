# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module ExtensionLifecycle
          extend self

          def run_lifecycle(generation:, review:)
            config = github_config
            return { success: false, error: :github_not_enabled } unless config[:enabled]
            return { success: false, error: :target_repo_missing } unless config[:target_repo]

            owner, repo = config[:target_repo].split('/')
            name = generation[:name] || generation[:generation_id]
            branch_name = "#{config[:branch_prefix]}-#{name}-#{Time.now.strftime('%Y%m%d%H%M%S')}"

            branch = create_lifecycle_branch(owner: owner, repo: repo,
                                             branch: branch_name, from_ref: config[:target_branch])
            return branch unless branch[:success]

            commit = commit_generated_files(owner: owner, repo: repo, branch: branch_name,
                                            generation: generation)
            return commit unless commit[:success]

            pr = open_pull_request(owner: owner, repo: repo, branch: branch_name,
                                   base: config[:target_branch], generation: generation, review: review)
            return pr unless pr[:success]

            label_pull_request(owner: owner, repo: repo, pull_number: pr[:pull_number],
                               labels: config[:pr_labels])

            handle_auto_merge(owner: owner, repo: repo, pull_number: pr[:pull_number],
                              config: config, review: review)

            { success: true, pull_number: pr[:pull_number], html_url: pr[:html_url],
              branch: branch_name, generation_id: generation[:generation_id] }
          rescue StandardError => e
            log.warn("ExtensionLifecycle failed: #{e.message}")
            { success: false, error: e.message }
          end

          private

          def create_lifecycle_branch(owner:, repo:, branch:, from_ref:)
            return { success: false, error: :github_runner_unavailable } unless github_runner_available?

            github_client.create_branch(owner: owner, repo: repo, branch: branch, from_ref: from_ref)
          end

          def commit_generated_files(owner:, repo:, branch:, generation:)
            return { success: false, error: :github_runner_unavailable } unless github_runner_available?

            files = build_file_list(generation)
            message = "add auto-generated #{generation[:name]} from gap #{generation[:gap_id]}"

            github_client.commit_files(owner: owner, repo: repo, branch: branch, files: files, message: message)
          end

          def open_pull_request(owner:, repo:, branch:, base:, generation:, review:) # rubocop:disable Metrics/ParameterLists
            return { success: false, error: :github_runner_unavailable } unless github_runner_available?

            body = build_pr_body(generation: generation, review: review)
            result = github_client.create_pull_request(
              owner: owner, repo: repo, title: "auto-generated: #{generation[:name]}",
              head: branch, base: base, body: body
            )

            pr = result[:result] || {}
            { success: true, pull_number: pr['number'], html_url: pr['html_url'] }
          rescue StandardError => e
            { success: false, error: e.message }
          end

          def label_pull_request(owner:, repo:, pull_number:, labels:)
            return { success: true } unless pull_number && labels&.any?
            return { success: false, error: :github_runner_unavailable } unless github_runner_available?

            github_client.add_labels(owner: owner, repo: repo, issue_number: pull_number, labels: labels)
          rescue StandardError => e
            log.warn("Label failed: #{e.message}")
            { success: false, error: e.message }
          end

          def handle_auto_merge(owner:, repo:, pull_number:, config:, review:)
            return unless config[:auto_merge] && review[:verdict]&.to_sym == :approve

            github_client.merge_pull_request(
              owner: owner, repo: repo, pull_number: pull_number,
              commit_title: 'auto-merge: generated extension'
            )
          rescue StandardError => e
            log.warn("Auto-merge failed: #{e.message}")
          end

          def build_file_list(generation)
            files = []
            files << { path: generation[:file_path], content: generation[:code] } if generation[:code]
            files << { path: generation[:spec_path], content: generation[:spec_code] } if generation[:spec_code]
            files
          end

          def build_pr_body(generation:, review:)
            stages = (review[:stages] || {}).map do |name, stage|
              passed = stage.is_a?(Hash) && stage[:passed] ? 'pass' : 'fail'
              "| #{name} | #{passed} | |"
            end.join("\n")

            <<~BODY
              ## Auto-Generated Extension

              **Gap**: #{generation[:gap_type]} - "#{generation[:name]}"
              **Tier**: #{generation[:tier]}
              **Generation ID**: #{generation[:generation_id]}

              ### Validation Results

              | Stage | Result | Details |
              |-------|--------|---------|
              #{stages}

              ### Files

              - `#{generation[:file_path]}` - Runner implementation
              - `#{generation[:spec_path]}` - Specs
            BODY
          end

          def github_config
            return default_config unless defined?(Legion::Settings)

            settings = Legion::Settings.dig(:codegen, :self_generate, :github) || {}
            default_config.merge(settings)
          rescue StandardError
            default_config
          end

          def default_config
            {
              enabled: false, target_repo: nil, target_branch: 'main',
              auto_merge: false, pr_labels: %w[auto-generated needs-review],
              branch_prefix: 'feature/auto-generated'
            }
          end

          def github_runner_available?
            defined?(Legion::Extensions::Github::Client)
          end

          def github_client
            @github_client ||= Legion::Extensions::Github::Client.new(**github_connection_opts)
          end

          def github_connection_opts
            return {} unless defined?(Legion::Settings)

            { token: Legion::Settings.dig(:github, :token) }
          rescue StandardError
            {}
          end

          def log
            return Legion::Logging if defined?(Legion::Logging)

            @log ||= Object.new.tap do |nl|
              %i[debug info warn error fatal].each { |m| nl.define_singleton_method(m) { |*| nil } }
            end
          end
        end
      end
    end
  end
end
