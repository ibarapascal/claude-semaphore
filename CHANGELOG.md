# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2026-03-17

### Fixed
- **Terminal.app exits when resetting background color** — OSC 111
  (`\033]111\007`) causes Terminal.app to exit cleanly (no crash report) when
  processing the sequence, likely due to its parser partially matching OSC 11
  then encountering unexpected input. Replaced all OSC 111 usage with OSC 11
  set to Terminal.app's default background color `(5866, 5866, 5866)`.

### Changed
- Increased red/green brightness ~25% to better match v0.1 AppleScript appearance

## [0.2.1] - 2026-03-17

### Fixed
- **Escape sequences not working** — v0.2.0 used OSC 6 (`\033]6;1;bg;...`), which
  is an iTerm2 proprietary sequence that Terminal.app silently ignores. Switched to
  OSC 11 (`\033]11;rgb:RR/GG/BB\007`), which is the xterm standard supported by
  Terminal.app. Reset uses OSC 111 (`\033]111\007`) to restore profile default color.

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
