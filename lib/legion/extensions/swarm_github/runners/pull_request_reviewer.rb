# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module PullRequestReviewer
          def review_pull_request(owner:, repo:, pull_number:)
            files = fetch_pr_files(owner: owner, repo: repo, pull_number: pull_number)
            return { status: 'skipped', reason: 'no files' } if files.empty?

            diff_text = files.map { |f| "#{f[:filename]}:\n#{f[:patch]}" }.join("\n\n")
            review = generate_review(diff_text)

            {
              status:         'reviewed',
              pr:             "#{owner}/#{repo}##{pull_number}",
              files_reviewed: files.size,
              comments:       review[:comments] || [],
              summary:        review[:summary]
            }
          end

          private

          def fetch_pr_files(owner:, repo:, pull_number:)
            return [] unless defined?(Legion::Extensions::Github::Client)

            Legion::Extensions::Github::Client.new.list_pull_request_files(
              owner: owner, repo: repo, pull_number: pull_number
            )[:result] || []
          rescue StandardError
            []
          end

          def generate_review(diff_text)
            return { summary: 'LLM unavailable', comments: [] } unless defined?(Legion::LLM)

            result = Legion::LLM.chat(
              message: "#{code_review_prompt}\n\n#{diff_text[0..12_000]}"
            )
            ::JSON.parse(result[:content] || '{}', symbolize_names: true)
          rescue StandardError => e
            { summary: "Review failed: #{e.message}", comments: [] }
          end

          def code_review_prompt
            <<~PROMPT
              Review this code diff. Return JSON with:
              - "summary": 1-2 sentence overall assessment
              - "comments": array of {"file", "line", "severity", "message"}
              Severity: info, warning, error. Focus on bugs and security issues.
            PROMPT
          end
        end
      end
    end
  end
end
