# frozen_string_literal: true

require_relative '../helpers/mesh_integration'

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module PrPipeline
          REVIEWABLE_ACTIONS = %w[opened synchronize reopened].freeze
          DEFAULT_SLACK_CHANNEL = '#code-reviews'

          def run_review_pipeline(owner:, repo:, pull_number:, slack_channel: nil, **opts)
            channel = slack_channel || DEFAULT_SLACK_CHANNEL
            issue_number = opts[:issue_number]

            review = review_pull_request(owner: owner, repo: repo, pull_number: pull_number)
            return { review: review, post: nil, notify: nil } unless review[:status] == 'reviewed'

            post = post_review(owner: owner, repo: repo, pull_number: pull_number, review: review)
            notify = notify_review(channel: channel, pull_ref: "#{owner}/#{repo}##{pull_number}",
                                   review: review, post_result: post)

            result = { review: review, post: post, notify: notify }
            bridge_review_to_issue(repo: "#{owner}/#{repo}", issue_number: issue_number,
                                   review_result: result)
            result
          end

          def run_review_pipeline_from_webhook(payload:, slack_channel: nil, **)
            action = payload['action']
            return { skipped: true, reason: 'action not reviewable' } unless REVIEWABLE_ACTIONS.include?(action)

            full_name = payload.dig('repository', 'full_name') || ''
            owner, repo = full_name.split('/', 2)
            pull_number = payload.dig('pull_request', 'number')

            run_review_pipeline(owner: owner, repo: repo, pull_number: pull_number,
                                slack_channel: slack_channel)
          end

          def bridge_review_to_issue(repo:, issue_number:, review_result:)
            return unless issue_number

            review_comments = review_result.dig(:review, :comments) || []
            blocker_severities = %w[critical high].freeze
            approved = review_comments.none? { |c| blocker_severities.include?(c[:severity]&.to_s&.downcase) }
            @issue_tracker&.record_validation(
              "#{repo}##{issue_number}",
              validator: :code_review,
              approved:  approved
            )
          end

          def handle_mesh_review_request(payload:, charter_id: nil, **)
            owner = payload[:owner] || payload['owner']
            repo = payload[:repo] || payload['repo']
            pull_number = payload[:pull_number] || payload['pull_number']

            return { success: false, reason: :missing_params } unless owner && repo && pull_number

            cid = charter_id || "mesh-review-#{owner}-#{repo}-#{pull_number}"
            Helpers::MeshIntegration.record_review_start(
              charter_id: cid, owner: owner, repo: repo, pull_number: pull_number
            )

            result = run_review_pipeline(owner: owner, repo: repo, pull_number: pull_number)

            Helpers::MeshIntegration.record_review_complete(
              charter_id: cid, owner: owner, repo: repo, pull_number: pull_number, result: result
            )

            result.merge(success: true)
          end
        end
      end
    end
  end
end
