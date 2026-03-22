# frozen_string_literal: true

require 'legion/extensions/swarm_github/version'
require 'legion/extensions/swarm_github/helpers/pipeline'
require 'legion/extensions/swarm_github/helpers/issue_tracker'
require 'legion/extensions/swarm_github/helpers/mesh_integration'
require 'legion/extensions/swarm_github/runners/github_swarm'
require 'legion/extensions/swarm_github/runners/pull_request_reviewer'
require 'legion/extensions/swarm_github/helpers/diff_chunker'
require 'legion/extensions/swarm_github/runners/review_poster'
require 'legion/extensions/swarm_github/runners/review_notifier'
require 'legion/extensions/swarm_github/runners/pr_pipeline'

module Legion
  module Extensions
    module SwarmGithub
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
