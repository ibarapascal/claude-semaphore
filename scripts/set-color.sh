#!/bin/bash
# Claude Semaphore - Change Terminal.app tab background color based on Claude Code session state
#
# Color states:
#   Default        - SessionEnd / green fades after timeout
#   Red  (47,0,0)  - UserPromptSubmit / PreToolUse / PreCompact (busy)
#   Green (0,31,0) - Stop (idle, waiting for user input)
#
# Uses Terminal.app proprietary ANSI escape sequences instead of AppleScript
# to avoid cross-process Apple Event overhead and heap corruption risk.

FADE_TIMEOUT=${FADE_TIMEOUT:-600}

# Read stdin JSON, parse with bash regex (avoids spawning python3 each time)
INPUT=$(cat)
EVENT=""
[[ "$INPUT" =~ \"hook_event_name\":\"([^\"]+)\" ]] && EVENT="${BASH_REMATCH[1]}"

# Walk process tree upward to find tty
get_tty() {
  local pid=$$
  while [ "$pid" != "1" ] && [ "$pid" != "0" ] && [ -n "$pid" ]; do
    local t
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$t" ] && [ "$t" != "??" ]; then
      echo "/dev/$t"
      return
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

MY_TTY=$(get_tty)
[ -z "$MY_TTY" ] && exit 0

# State files (per-tty)
TTY_SAFE=$(echo "$MY_TTY" | tr '/' '_')
STATE_FILE="/tmp/claude-semaphore-state${TTY_SAFE}"
FADE_PID_FILE="/tmp/claude-semaphore-fade${TTY_SAFE}"

# Set tab background color via Terminal.app ANSI escape sequences
# Args: r g b (0-255 each)
set_color() {
  printf '\033]6;1;bg;red;brightness;%d\007\033]6;1;bg;green;brightness;%d\007\033]6;1;bg;blue;brightness;%d\007' "$1" "$2" "$3" > "$MY_TTY" 2>/dev/null
}

# Reset tab background color to Terminal.app default
reset_color() {
  printf '\033]6;1;bg;*;default\007' > "$MY_TTY" 2>/dev/null
}

# Kill previous fade-out background process
kill_fade() {
  if [ -f "$FADE_PID_FILE" ]; then
    local old_pid
    old_pid=$(cat "$FADE_PID_FILE" 2>/dev/null)
    if [ -n "$old_pid" ]; then
      kill "$old_pid" 2>/dev/null
    fi
    rm -f "$FADE_PID_FILE"
  fi
}

# Start background process: restore default after timeout
start_fade() {
  kill_fade
  (
    sleep "$FADE_TIMEOUT"
    reset_color
    echo "default" > "$STATE_FILE"
    rm -f "$FADE_PID_FILE"
  ) </dev/null >/dev/null 2>&1 &
  echo $! > "$FADE_PID_FILE"
  disown
}

# Determine color based on event
case "$EVENT" in
  SessionStart)
    kill_fade
    COLOR="green"
    ;;
  UserPromptSubmit|PreToolUse|PreCompact)
    kill_fade
    COLOR="red"
    ;;
  Stop)
    kill_fade
    COLOR="green"
    NEED_FADE=1
    ;;
  SessionEnd)
    kill_fade
    reset_color
    rm -f "$STATE_FILE"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

# Dedup: skip if color hasn't changed
CURRENT_STATE=""
[ -f "$STATE_FILE" ] && CURRENT_STATE=$(cat "$STATE_FILE")
[ "$CURRENT_STATE" = "$COLOR" ] && exit 0

# Apply color (0-255 scale)
case "$COLOR" in
  red)   set_color 47 0 0 ;;
  green) set_color 0 31 0 ;;
esac

echo "$COLOR" > "$STATE_FILE"

# On Stop, start fade-out timer to restore default
[ "${NEED_FADE:-0}" = "1" ] && start_fade
exit 0
