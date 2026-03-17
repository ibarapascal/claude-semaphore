# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-17

### Added
- Initial release — migrated from workspace terminal-status plugin
- Red/green terminal tab background color indicator for Claude Code session status
- Per-window isolation via tty matching
- Deduplication optimization with state file caching
- Original color save/restore on session start/end
- Green fade-out after configurable timeout (default 10 minutes)
- Shell wrapper support for Ctrl+C graceful cleanup
