# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module ReviewPoster
          def post_review(owner:, repo:, pull_number:, review:, **)
            return { posted: false, reason: 'review was skipped' } unless review[:status] == 'reviewed'

            return { posted: false, reason: 'lex-github not available' } unless defined?(Legion::Extensions::Github::Client)

            body = format_review_body(review)
            inline_comments = format_inline_comments(review[:comments] || [])

            result = Legion::Extensions::Github::Client.new.create_review(
              owner: owner, repo: repo, pull_number: pull_number,
              body: body, comments: inline_comments
            )

            review_id = result.dig(:result, 'id') || result.dig(:result, :id)
            { posted: true, review_id: review_id, comments_count: inline_comments.size }
          rescue StandardError => e
            { posted: false, reason: "post failed: #{e.message}" }
          end

          private

          def format_review_body(review)
            parts = ["**Legion AI Review** (#{review[:files_reviewed]} file#{'s' if review[:files_reviewed] != 1} reviewed)"]
            parts << ''
            parts << review[:summary] if review[:summary]

            comments = review[:comments] || []
            if comments.any?
              by_severity = comments.group_by { |c| c[:severity] || 'info' }
              counts = by_severity.map { |sev, list| "#{list.size} #{sev}" }.join(', ')
              parts << ''
              parts << "Findings: #{counts}"
            end

            parts.join("\n")
          end

          def format_inline_comments(comments)
            comments.filter_map do |c|
              next unless c[:file] && c[:message]

              severity_icon = case c[:severity]
                              when 'error' then '**Error**'
                              when 'warning' then 'Warning'
                              else 'Note'
                              end

              {
                path:     c[:file],
                position: c[:line] || 1,
                body:     "#{severity_icon}: #{c[:message]}"
              }
            end
          end
        end
      end
    end
  end
end
