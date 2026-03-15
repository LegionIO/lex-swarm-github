# Changelog

## [0.1.1] - 2026-03-14

### Added
- `StaleIssues` actor (Every 3600s) — calls `mark_stale_issues` to transition non-terminal issues that have exceeded `STALE_TIMEOUT` (86400s) to `:stale` state, enforcing the previously defined-but-not-enforced constant

## [0.1.0] - 2026-03-13

### Added
- Initial release
