# frozen_string_literal: true

require 'legion/extensions/swarm_github/version'
require 'legion/extensions/swarm_github/helpers/pipeline'
require 'legion/extensions/swarm_github/helpers/issue_tracker'
require 'legion/extensions/swarm_github/runners/github_swarm'

module Legion
  module Extensions
    module SwarmGithub
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
