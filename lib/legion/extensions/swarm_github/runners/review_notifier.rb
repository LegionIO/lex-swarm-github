# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module ReviewNotifier
          def notify_review(channel:, pull_ref:, review:, post_result:, **)
            return { notified: false, reason: 'review not posted' } unless post_result[:posted]

            return { notified: false, reason: 'lex-slack not available' } unless defined?(Legion::Extensions::Slack::Client)

            message = format_slack_message(pull_ref: pull_ref, review: review, post_result: post_result)
            result = Legion::Extensions::Slack::Client.new.post_message(
              channel: channel, text: message
            )

            { notified: result[:ok] == true, channel: channel, ts: result[:ts] }
          rescue StandardError => e
            log.warn(e.message) if respond_to?(:log, true)
            { notified: false, reason: "slack error: #{e.message}" }
          end

          private

          def format_slack_message(pull_ref:, review:, post_result:)
            comments_count = post_result[:comments_count] || 0
            files = review[:files_reviewed] || 0

            parts = [":mag: *AI Code Review* for `#{pull_ref}` (#{files} file#{'s' if files != 1})"]
            parts << review[:summary] if review[:summary]

            parts << if comments_count.positive?
                       ":memo: #{comments_count} comment#{'s' if comments_count != 1} posted"
                     else
                       ':white_check_mark: No issues found'
                     end

            parts.join("\n")
          end
        end
      end
    end
  end
end
