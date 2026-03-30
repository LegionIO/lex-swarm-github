# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Runners
        module GithubSwarm
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          def ingest_issue(repo:, issue_number:, title:, labels: [], **)
            key = issue_tracker.track(repo: repo, issue_number: issue_number, title: title, labels: labels)
            log.info "[github-swarm] ingested: key=#{key} title=#{title}"
            { tracked: true, key: key, state: :received }
          end

          def claim_issue(key:, **)
            result = issue_tracker.transition(key, :found)
            if result == :found
              log.info "[github-swarm] claimed: key=#{key}"
              { claimed: true, state: :found }
            else
              log.debug "[github-swarm] claim failed: key=#{key} result=#{result}"
              { error: result || :not_found }
            end
          end

          def start_fix(key:, **)
            issue_tracker.transition(key, :fixing)
            attempt = issue_tracker.record_fix_attempt(key)
            if attempt && attempt > Helpers::Pipeline::MAX_FIX_ATTEMPTS
              log.warn "[github-swarm] max attempts exceeded: key=#{key} attempts=#{attempt}"
              { error: :max_attempts_exceeded, attempts: attempt }
            else
              log.info "[github-swarm] fix started: key=#{key} attempt=#{attempt}"
              { fixing: true, attempt: attempt }
            end
          end

          def submit_validation(key:, validator:, approved:, reason: nil, **)
            consensus = issue_tracker.record_validation(key, validator: validator,
                                                            approved: approved, reason: reason)
            if consensus
              log.info "[github-swarm] validation: key=#{key} validator=#{validator} approved=#{approved} consensus=#{consensus}"
              { recorded: true, consensus: consensus }
            else
              log.debug "[github-swarm] validation failed: key=#{key} not found"
              { error: :not_found }
            end
          end

          def attach_pr(key:, pr_number:, **)
            result = issue_tracker.attach_pr(key, pr_number: pr_number)
            if result
              log.info "[github-swarm] PR attached: key=#{key} pr=##{pr_number}"
              { attached: true, pr_number: pr_number }
            else
              log.debug "[github-swarm] PR attach failed: key=#{key} not found"
              { error: :not_found }
            end
          end

          def get_issue(key:, **)
            issue = issue_tracker.get(key)
            log.debug "[github-swarm] get: key=#{key} found=#{!issue.nil?}"
            issue ? { found: true, issue: issue } : { found: false }
          end

          def issues_by_state(state:, **)
            issues = issue_tracker.by_state(state)
            log.debug "[github-swarm] by_state: state=#{state} count=#{issues.size}"
            { issues: issues, count: issues.size }
          end

          def pipeline_status(**)
            status = Helpers::Pipeline::STATES.to_h do |state|
              [state, issue_tracker.by_state(state).size]
            end
            summary = status.select { |_, v| v.positive? }.map { |k, v| "#{k}=#{v}" }.join(' ')
            log.debug "[github-swarm] pipeline: total=#{issue_tracker.count} #{summary}"
            { states: status, total: issue_tracker.count }
          end

          def mark_stale_issues(**)
            terminal  = %i[approved pr_open rejected stale]
            now       = Time.now.utc
            timeout   = Helpers::Pipeline::STALE_TIMEOUT
            stale_keys = []
            issue_tracker.issues.each do |key, issue|
              next if terminal.include?(issue[:state])
              next unless now - issue[:updated_at] > timeout

              issue_tracker.transition(key, :stale)
              stale_keys << key
            end
            log.debug "[swarm-github] stale check: checked=#{issue_tracker.count} stale=#{stale_keys.size}"
            { checked: issue_tracker.count, marked_stale: stale_keys.size, stale_keys: stale_keys }
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
