# frozen_string_literal: true

require 'legion/extensions/swarm_github/helpers/pipeline'
require 'legion/extensions/swarm_github/helpers/issue_tracker'
require 'legion/extensions/swarm_github/runners/github_swarm'

module Legion
  module Extensions
    module SwarmGithub
      class Client
        include Runners::GithubSwarm

        def initialize(**)
          @issue_tracker = Helpers::IssueTracker.new
        end

        private

        attr_reader :issue_tracker
      end
    end
  end
end
