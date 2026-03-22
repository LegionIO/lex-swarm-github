# frozen_string_literal: true

require 'legion/extensions/swarm_github/helpers/pipeline'
require 'legion/extensions/swarm_github/helpers/issue_tracker'
require 'legion/extensions/swarm_github/runners/github_swarm'
require 'legion/extensions/swarm_github/runners/pull_request_reviewer'
require 'legion/extensions/swarm_github/runners/review_poster'
require 'legion/extensions/swarm_github/runners/review_notifier'
require 'legion/extensions/swarm_github/runners/pr_pipeline'

module Legion
  module Extensions
    module SwarmGithub
      class Client
        include Runners::GithubSwarm
        include Runners::PullRequestReviewer
        include Runners::ReviewPoster
        include Runners::ReviewNotifier
        include Runners::PrPipeline

        def initialize(**)
          @issue_tracker = Helpers::IssueTracker.new
        end

        private

        attr_reader :issue_tracker
      end
    end
  end
end
