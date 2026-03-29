# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module PullRequestReviewer
          def review_pull_request(owner:, repo:, pull_number:)
            files = fetch_pr_files(owner: owner, repo: repo, pull_number: pull_number)
            return { status: 'skipped', reason: 'no files' } if files.empty?

            review = generate_review(files)

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
          rescue StandardError => e
            log.warn(e.message) if respond_to?(:log, true)
            []
          end

          def generate_review(files)
            chunks = Helpers::DiffChunker.chunk_files(files)
            reviews = chunks.map do |chunk|
              diff_text = chunk.map { |f| "--- #{f[:filename]} ---\n#{f[:patch]}" }.join("\n\n")
              prompt = code_review_prompt(diff_text)
              response = Legion::LLM.chat(message: prompt, caller: { extension: 'lex-swarm-github' })
              parse_review_response(response)
            end
            merge_chunk_reviews(reviews)
          rescue StandardError => e
            log.warn("Review generation failed: #{e.message}") if respond_to?(:log, true)
            { summary: 'Review generation failed', comments: [] }
          end

          def merge_chunk_reviews(reviews)
            merged_comments = reviews.flat_map { |r| r[:comments] || [] }
            summaries = reviews.map { |r| r[:summary] }.compact
            {
              summary:  summaries.join("\n\n"),
              comments: merged_comments
            }
          end

          def parse_review_response(response)
            Legion::JSON.parse(response)
          rescue StandardError => e
            log.warn(e.message) if respond_to?(:log, true)
            { summary: response.to_s, comments: [] }
          end

          def code_review_prompt(diff_text)
            <<~PROMPT
              Review this code diff. Return JSON with:
              - "summary": 1-2 sentence overall assessment
              - "comments": array of {"file", "line", "severity", "message"}
              Severity: info, warning, error. Focus on bugs and security issues.

              #{diff_text}
            PROMPT
          end
        end
      end
    end
  end
end
