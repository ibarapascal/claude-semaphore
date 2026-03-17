# Claude Semaphore - Development Guide

## Overview

Claude Code plugin that changes Terminal.app tab background color to indicate session status. Red means busy, green means waiting for input. Per-window isolation via tty matching.

---

## Architecture

```
Hook Event (SessionStart / UserPromptSubmit / PreToolUse / PreCompact / Stop / SessionEnd)
       |
       v
  set-color.sh (reads stdin JSON, extracts hook_event_name)
       |
       ├─ Walk process tree → find tty
       ├─ Dedup check (state file) → skip if same color
       ├─ ANSI escape sequence → write to tty device → set tab background color
       ├─ SessionEnd → reset to default color, cleanup
       └─ Stop → set green + spawn fade-out background process
```

**Color scheme:**

| State | Color | RGB | Trigger |
|-------|-------|-----|---------|
| Busy | Red | `(47, 0, 0)` | `UserPromptSubmit` / `PreToolUse` / `PreCompact` |
| Idle | Green | `(0, 31, 0)` | `Stop` / `SessionStart` |
| No session | Default | Terminal.app default | `SessionEnd` / Fade timeout |

---

## Directory Structure

```
claude-semaphore/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Local marketplace config
├── hooks/
│   └── hooks.json           # Hook event bindings
├── scripts/
│   ├── set-color.sh         # Core script (called by hooks)
│   └── reset-color.sh       # Color reset (called by shell wrapper)
├── .github/
│   └── workflows/
│       └── release.yml      # Auto-release on version bump
├── CLAUDE.md                # This file
├── README.md                # User documentation
├── CHANGELOG.md             # Version history
└── LICENSE                  # MIT
```

---

## Key Files

### set-color.sh

Core hook script. Handles all hook events:
- Reads stdin JSON with bash regex (no python/jq dependency)
- Finds tty by walking process tree upward
- Deduplicates via state file (`/tmp/claude-semaphore-state_dev_ttysXXX`)
- Sets color via OSC 11 escape sequence written directly to tty device (~0ms, no process spawn)
- Manages fade-out background process for green state

### reset-color.sh

Shell wrapper fallback. Called after Claude exits to restore original color when `SessionEnd` hook doesn't fire (e.g., Ctrl+C).

### hooks.json

Binds six hook events to `set-color.sh`:
- `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PreCompact`, `Stop`, `SessionEnd`

All use `$CLAUDE_PLUGIN_ROOT` for path resolution.

---

## Temporary Files

All state files in `/tmp/`, per-tty isolated:

| File | Purpose |
|------|---------|
| `claude-semaphore-state_dev_ttysXXX` | Current color state (dedup) |
| `claude-semaphore-fade_dev_ttysXXX` | Fade background process PID |

---

## Known Limitations

- **Terminal.app only** — Uses Terminal.app proprietary ANSI escape sequences; iTerm2/Kitty/Alacritty not supported
- **Not a true border** — Changes background color, not window border (Terminal.app has no border API)
- **No exact color restore** — SessionEnd resets to Terminal.app default; cannot read/restore user's custom per-tab colors (ANSI escape sequences are write-only)
- **Ctrl+C cleanup** — Requires shell wrapper (not part of plugin API)

---

## Development Workflow

### Quick Testing (No Install)

```bash
claude --plugin-dir /path/to/claude-semaphore
```

### Full Install Test

```bash
claude plugin uninstall claude-semaphore@local-dev
claude plugin install claude-semaphore@local-dev
claude plugin list
```

### Debug Scripts

```bash
# Test set-color directly (simulate a Stop event)
echo '{"hook_event_name":"Stop"}' | bash scripts/set-color.sh

# Test reset-color
bash scripts/reset-color.sh
```

---

## Configuration

Environment variable `FADE_TIMEOUT` (seconds) controls how long green persists before fading to original color. Default: 600 (10 minutes).

```bash
export FADE_TIMEOUT=600
```

---

## Version Management

When updating version or changelog, always update all three together:

1. `.claude-plugin/plugin.json` — `version` field
2. `README.md` — version badge
3. `CHANGELOG.md` — add new version entry

**Trigger rule**: Any version bump or changelog update must update all three files.

---

## Release Checklist

- [ ] Scripts tested on macOS Terminal.app
- [ ] Deduplication verified (no redundant escape sequence writes)
- [ ] Default color reset works on SessionEnd
- [ ] Fade-out works after timeout
- [ ] Shell wrapper reset-color.sh works
- [ ] README.md updated
- [ ] CHANGELOG.md updated
- [ ] plugin.json version bumped
- [ ] All content in English

---

# Contributing Guidelines

## Language Policy

**All content in this plugin MUST be in English only.**

This includes:
- Code comments
- Documentation (README, CLAUDE.md)
- Hook configurations
- Output messages
- Commit messages

No exceptions. This ensures consistency for potential official marketplace submission.
