# Changelog

## [0.3.1] - 2026-03-28

### Added
- `Runners::ExtensionLifecycle` — orchestrates autonomous extension github pipeline: branch creation, file commit, PR open, label, optional auto-merge
- `Actor::LifecycleSubscriber` — subscription actor that triggers lifecycle runner when generation review verdict is `approve` and github lifecycle is enabled
- Added K-factor adversarial PR review (review_k: kwarg, default 1, settings-configurable)

## [0.3.0] - 2026-03-24

### Changed
- Wire DiffChunker into PullRequestReviewer for chunked large-PR review
- Add APPROVE/REQUEST_CHANGES review events based on comment severity
- Bridge review results to issue tracker validation

### Fixed
- ReviewNotifier Slack client instantiation passing stray kwargs

## [0.2.3] - 2026-03-23

### Changed
- route llm calls through pipeline when available, add caller identity for attribution

## [0.2.2] - 2026-03-22

### Changed
- Add legion-logging, legion-settings, legion-json, legion-cache, legion-crypt, legion-data, legion-transport as runtime dependencies
- Replace direct Legion::Logging calls with injected log helper (log.info/debug/warn) in Runners::GithubSwarm
- Update spec_helper with real sub-gem helper stubs

## [0.2.1] - 2026-03-22

### Added
- `Helpers::MeshIntegration` module with `register_reviewer`, `record_review_start`, and `record_review_complete` methods; all external calls guarded with `defined?()` so lex-mesh and lex-swarm remain optional deps
- `Runners::PrPipeline#handle_mesh_review_request` — entry point for mesh-delegated reviews; extracts owner/repo/pull_number from symbol- or string-keyed payload, tracks review lifecycle in the swarm workspace, and returns pipeline result merged with `success: true`
- 22 new specs covering `Helpers::MeshIntegration` and `handle_mesh_review_request` (availability guards, ordered workspace tracking, charter_id generation, missing-param guard)

## [0.1.2] - 2026-03-21

### Added
- `Runners::PullRequestReviewer` with `review_pull_request` method for LLM-powered code review
- Fetches PR diff via lex-github Client, generates review via Legion::LLM
- Returns structured comments with file, line, severity, and message

## [0.1.1] - 2026-03-14

### Added
- `StaleIssues` actor (Every 3600s) — calls `mark_stale_issues` to transition non-terminal issues that have exceeded `STALE_TIMEOUT` (86400s) to `:stale` state, enforcing the previously defined-but-not-enforced constant

## [0.1.0] - 2026-03-13

### Added
- Initial release
