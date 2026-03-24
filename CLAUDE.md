# lex-swarm-github

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

GitHub-specific swarm pipeline for the LegionIO cognitive architecture. Implements a state-machine-driven issue processing workflow with adversarial validation (3 independent validators required), fix attempt tracking, and automatic label management.

## Gem Info

- **Gem name**: `lex-swarm-github`
- **Version**: `0.2.0`
- **Module**: `Legion::Extensions::SwarmGithub`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/swarm_github/
  version.rb
  helpers/
    pipeline.rb      # STATES, LABELS, PIPELINE_ROLES, ADVERSARIAL_REVIEW_K, MAX_FIX_ATTEMPTS,
                     # STALE_TIMEOUT, valid_state?, label_for_state, next_state
    issue_tracker.rb # IssueTracker class - keyed by "repo#issue_number"
  runners/
    github_swarm.rb  # ingest_issue, claim_issue, start_fix, submit_validation, attach_pr,
                     # get_issue, issues_by_state, pipeline_status, mark_stale_issues
  actors/
    stale_issues.rb  # StaleIssues - Every 3600s, calls mark_stale_issues
spec/
  legion/extensions/swarm_github/
    runners/
      github_swarm_spec.rb
    actors/
      stale_issues_spec.rb
    client_spec.rb
```

## Key Constants (Helpers::Pipeline)

```ruby
STATES = %i[received found fixing validating approved pr_open rejected stale]
LABELS = STATES.map { |s| :"swarm:#{s}" }  # e.g., :"swarm:received"
PIPELINE_ROLES       = %i[finder fixer validator pr_swarm]
ADVERSARIAL_REVIEW_K = 3     # validators required for consensus
MAX_FIX_ATTEMPTS     = 3
STALE_TIMEOUT        = 86_400  # 24 hours (not enforced in current implementation)
```

`next_state` hash maps forward transitions only: `received->found->fixing->validating->approved->pr_open`.

## IssueTracker Class

Key format: `"#{repo}##{issue_number}"` (e.g., `"LegionIO/lex-tick#42"`).

Issue structure:
```ruby
{
  repo: "...", issue_number: 42, title: "...", labels: [],
  state: :received, fix_attempts: 0, validations: [], pr_number: nil,
  created_at: Time, updated_at: Time
}
```

`transition(key, to_state)` validates state, updates `state` and `labels` array (single label matching current state).

`record_fix_attempt` increments `fix_attempts` and returns the new count.

`record_validation` appends to `validations` array, then calls `check_validation_consensus` which counts approvals/rejections and returns `:approved`, `:rejected`, or `:pending` when `>= ADVERSARIAL_REVIEW_K` threshold is met.

`attach_pr` sets `pr_number` and transitions state to `:pr_open`.

## Actors

| Actor | Interval | Runner Method | What It Does |
|-------|----------|---------------|--------------|
| `StaleIssues` | Every 3600s | `mark_stale_issues` | Iterates all tracked issues; transitions any non-terminal issue (not `:approved`, `:pr_open`, `:rejected`, or `:stale`) that has not been updated within `STALE_TIMEOUT` (86400s) to `:stale` state |

## Runner Logic Notes

`start_fix` calls both `transition(key, :fixing)` AND `record_fix_attempt`. If `fix_attempts > MAX_FIX_ATTEMPTS`, returns `{ error: :max_attempts_exceeded }`.

`claim_issue` calls `transition(key, :found)` — returns the state symbol (`:found`) on success, or `nil`/error symbol otherwise.

## Integration Points

- **lex-swarm**: this extension is a domain-specific implementation on top of the base swarm charter system; they can be used together but have independent state
- **lex-github** (extensions/): the underlying GitHub API calls (creating PRs, setting labels) are handled by `lex-github`, not this extension — this extension tracks pipeline state only
- **lex-mesh**: swarm agents in the GitHub pipeline communicate via mesh

## Development Notes

- `STALE_TIMEOUT` is now enforced by the `StaleIssues` actor — issues inactive for 24+ hours auto-transition to `:stale`
- `mark_stale_issues` checks `updated_at` (not `created_at`) — issues that receive any transition reset their staleness clock
- Labels in the issue tracker are the `swarm:*` labels (e.g., `swarm:fixing`); other GitHub labels from ingest are preserved in the initial `labels:` array but overwritten on first transition
- `check_validation_consensus` checks approvals and rejections independently — a tie does not resolve
