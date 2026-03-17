# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-17

### Changed
- **Replace AppleScript with ANSI escape sequences** for all color operations
  - Eliminates cross-process Apple Events that caused Terminal.app heap corruption
  - Reduces color change latency from ~130ms to <1ms
  - No longer spawns `osascript` processes
- Session end and fade-out now reset to Terminal.app default color instead of
  saving/restoring exact original color (ANSI escape sequences cannot read
  current background color, but `\033]6;1;bg;*;default\007` resets cleanly)
- Removed `claude-semaphore-original` temporary file (no longer needed)

### Fixed
- **Terminal.app crash** — high-frequency AppleScript Apple Events caused heap
  corruption in Terminal.app's main thread, manifesting as 4 different crash
  types (SIGABRT/SIGSEGV/SIGBUS/SIGTRAP) over 5 days. Root cause: cross-process
  `osascript` calls forced Terminal to traverse ObjC window/tab objects on the
  main thread, racing with its own rendering and tty-io threads. Crash reports
  consistently showed memory corruption signatures (`free_list_checksum_botch`,
  `objc_msgSend` use-after-free, `memmove` bus error, `CFGetTypeID` invalid
  tagged pointer). Switching to in-process ANSI escape sequences eliminates
  all cross-process communication with Terminal.app.

## [0.1.0] - 2026-03-17

### Added
- Initial release — migrated from workspace terminal-status plugin
- Red/green terminal tab background color indicator for Claude Code session status
- Per-window isolation via tty matching
- Deduplication optimization with state file caching
- Original color save/restore on session start/end
- Green fade-out after configurable timeout (default 10 minutes)
- Shell wrapper support for Ctrl+C graceful cleanup
