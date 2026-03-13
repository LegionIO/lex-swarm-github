# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module SwarmGithub
      module Helpers
        class IssueTracker
          attr_reader :issues

          def initialize
            @issues = {}
          end

          def track(repo:, issue_number:, title:, labels: [])
            key = "#{repo}##{issue_number}"
            @issues[key] = {
              repo:          repo,
              issue_number:  issue_number,
              title:         title,
              labels:        labels,
              state:         :received,
              fix_attempts:  0,
              validations:   [],
              pr_number:     nil,
              created_at:    Time.now.utc,
              updated_at:    Time.now.utc
            }
            key
          end

          def transition(key, to_state)
            issue = @issues[key]
            return nil unless issue
            return :invalid_state unless Pipeline.valid_state?(to_state)

            issue[:state] = to_state
            issue[:updated_at] = Time.now.utc
            issue[:labels] = [Pipeline.label_for_state(to_state)]
            to_state
          end

          def record_fix_attempt(key)
            issue = @issues[key]
            return nil unless issue

            issue[:fix_attempts] += 1
            issue[:fix_attempts]
          end

          def record_validation(key, validator:, approved:, reason: nil)
            issue = @issues[key]
            return nil unless issue

            issue[:validations] << { validator: validator, approved: approved, reason: reason, at: Time.now.utc }
            check_validation_consensus(key)
          end

          def attach_pr(key, pr_number:)
            issue = @issues[key]
            return nil unless issue

            issue[:pr_number] = pr_number
            issue[:state] = :pr_open
            issue[:updated_at] = Time.now.utc
          end

          def get(key)
            @issues[key]
          end

          def by_state(state)
            @issues.values.select { |i| i[:state] == state }
          end

          def count
            @issues.size
          end

          private

          def check_validation_consensus(key)
            issue = @issues[key]
            approvals = issue[:validations].count { |v| v[:approved] }
            rejections = issue[:validations].count { |v| !v[:approved] }

            if approvals >= Pipeline::ADVERSARIAL_REVIEW_K
              :approved
            elsif rejections >= Pipeline::ADVERSARIAL_REVIEW_K
              :rejected
            else
              :pending
            end
          end
        end
      end
    end
  end
end
