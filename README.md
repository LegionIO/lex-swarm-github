# lex-swarm-github

GitHub-specific swarm pipeline for brain-modeled agentic AI. Implements an automated issue processing pipeline with finder/fixer/validator roles, adversarial review, and state-machine-driven issue tracking.

## Overview

`lex-swarm-github` extends the base swarm system with a GitHub-specific workflow. Issues are ingested, claimed by finder agents, fixed by fixer agents, validated by multiple independent validators (adversarial review), and finally attached to a pull request. Each state transition is tracked and labeled.

## Pipeline States

```
received -> found -> fixing -> validating -> approved -> pr_open
                                         -> rejected
                                         -> stale
```

## Agent Roles

| Role | Responsibility |
|------|---------------|
| `finder` | Claims and analyzes issues |
| `fixer` | Implements fixes |
| `validator` | Reviews fixes independently (3 required) |
| `pr_swarm` | Manages PR creation and merge |

## Validation

- Requires 3 independent validator approvals for consensus (adversarial review)
- Maximum 3 fix attempts before `max_attempts_exceeded` error
- Issues stale after 24 hours without activity

## Installation

Add to your Gemfile:

```ruby
gem 'lex-swarm-github'
```

## Usage

### Processing an Issue

```ruby
require 'legion/extensions/swarm_github'

# 1. Ingest an issue from GitHub
result = Legion::Extensions::SwarmGithub::Runners::GithubSwarm.ingest_issue(
  repo: "LegionIO/lex-tick",
  issue_number: 42,
  title: "Tick mode transition doesn't respect SENTINEL_TIMEOUT",
  labels: ["bug", "tick"]
)
# => { tracked: true, key: "LegionIO/lex-tick#42", state: :received }

# 2. Finder claims it
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.claim_issue(
  key: "LegionIO/lex-tick#42"
)
# => { claimed: true, state: :found }

# 3. Fixer starts work
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.start_fix(
  key: "LegionIO/lex-tick#42"
)
# => { fixing: true, attempt: 1 }

# 4. Validators submit reviews (3 required for consensus)
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.submit_validation(
  key: "LegionIO/lex-tick#42",
  validator: "agent-validator-1",
  approved: true,
  reason: "Fix correctly checks both timeout conditions"
)

# 5. Attach PR when approved
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.attach_pr(
  key: "LegionIO/lex-tick#42",
  pr_number: 99
)
# => { attached: true, pr_number: 99 }
```

### Querying the Pipeline

```ruby
# Issues by state
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.issues_by_state(state: :validating)

# Full pipeline status
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.pipeline_status
# => { states: { received: 0, found: 1, fixing: 2, validating: 1, ... }, total: 4 }

# Specific issue
Legion::Extensions::SwarmGithub::Runners::GithubSwarm.get_issue(key: "LegionIO/lex-tick#42")
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
