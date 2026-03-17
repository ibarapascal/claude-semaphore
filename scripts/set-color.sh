#!/bin/bash
# Claude Semaphore - Change Terminal.app tab background color based on Claude Code session state
#
# Color states:
#   Default (original) - SessionEnd / green fades after timeout
#   Red {12000,0,0}    - UserPromptSubmit / PreToolUse / PreCompact (busy)
#   Green {0,8000,0}   - Stop (idle, waiting for user input)

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
ORIGINAL_FILE="/tmp/claude-semaphore-original${TTY_SAFE}"
FADE_PID_FILE="/tmp/claude-semaphore-fade${TTY_SAFE}"

# Set background color of the matching tab via AppleScript
set_color() {
  local r=$1 g=$2 b=$3
  osascript -e "
tell application \"Terminal\"
  repeat with w in windows
    repeat with t in tabs of w
      if tty of t is \"$MY_TTY\" then
        set background color of t to {$r, $g, $b}
        return
      end if
    end repeat
  end repeat
end tell
" 2>/dev/null
}

# Get current tab background color
get_current_color() {
  osascript -e "
tell application \"Terminal\"
  repeat with w in windows
    repeat with t in tabs of w
      if tty of t is \"$MY_TTY\" then
        return background color of t
      end if
    end repeat
  end repeat
end tell
" 2>/dev/null
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
    if [ -f "$ORIGINAL_FILE" ]; then
      IFS=', ' read -r r g b < "$ORIGINAL_FILE"
      set_color "$r" "$g" "$b"
    fi
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
    # Save original color, but skip our own status colors (crash remnants)
    ORIG=$(get_current_color)
    if [ -n "$ORIG" ]; then
      case "$ORIG" in
        "12000, 0, 0"|"0, 8000, 0") ;;  # red/green, skip
        *) echo "$ORIG" > "$ORIGINAL_FILE" ;;
      esac
    fi
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
    if [ -f "$ORIGINAL_FILE" ]; then
      IFS=', ' read -r r g b < "$ORIGINAL_FILE"
      set_color "$r" "$g" "$b"
      rm -f "$ORIGINAL_FILE" "$STATE_FILE"
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

# Dedup: skip osascript if color hasn't changed
CURRENT_STATE=""
[ -f "$STATE_FILE" ] && CURRENT_STATE=$(cat "$STATE_FILE")
[ "$CURRENT_STATE" = "$COLOR" ] && exit 0

# Apply color
case "$COLOR" in
  red)   set_color 12000 0 0 ;;
  green) set_color 0 8000 0 ;;
esac

echo "$COLOR" > "$STATE_FILE"

# On Stop, start fade-out timer to restore default
[ "${NEED_FADE:-0}" = "1" ] && start_fade
exit 0
