# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module GithubSwarm
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def ingest_issue(repo:, issue_number:, title:, labels: [], **)
            key = issue_tracker.track(repo: repo, issue_number: issue_number, title: title, labels: labels)
            { tracked: true, key: key, state: :received }
          end

          def claim_issue(key:, **)
            result = issue_tracker.transition(key, :found)
            result == :found ? { claimed: true, state: :found } : { error: result || :not_found }
          end

          def start_fix(key:, **)
            issue_tracker.transition(key, :fixing)
            attempt = issue_tracker.record_fix_attempt(key)
            if attempt && attempt > Helpers::Pipeline::MAX_FIX_ATTEMPTS
              { error: :max_attempts_exceeded, attempts: attempt }
            else
              { fixing: true, attempt: attempt }
            end
          end

          def submit_validation(key:, validator:, approved:, reason: nil, **)
            consensus = issue_tracker.record_validation(key, validator: validator,
                                                            approved: approved, reason: reason)
            if consensus
              { recorded: true, consensus: consensus }
            else
              { error: :not_found }
            end
          end

          def attach_pr(key:, pr_number:, **)
            result = issue_tracker.attach_pr(key, pr_number: pr_number)
            result ? { attached: true, pr_number: pr_number } : { error: :not_found }
          end

          def get_issue(key:, **)
            issue = issue_tracker.get(key)
            issue ? { found: true, issue: issue } : { found: false }
          end

          def issues_by_state(state:, **)
            issues = issue_tracker.by_state(state)
            { issues: issues, count: issues.size }
          end

          def pipeline_status(**)
            status = Helpers::Pipeline::STATES.to_h do |state|
              [state, issue_tracker.by_state(state).size]
            end
            { states: status, total: issue_tracker.count }
          end

          private

          def issue_tracker
            @issue_tracker ||= Helpers::IssueTracker.new
          end
        end
      end
    end
  end
end
