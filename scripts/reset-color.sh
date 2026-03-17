#!/bin/bash
# Restore terminal background color after Claude exits (called by shell wrapper)
MY_TTY=$(tty 2>/dev/null)
[ -z "$MY_TTY" ] || [ "$MY_TTY" = "not a tty" ] && exit 0

TTY_SAFE=$(echo "$MY_TTY" | tr '/' '_')
ORIGINAL_FILE="/tmp/claude-semaphore-original${TTY_SAFE}"
STATE_FILE="/tmp/claude-semaphore-state${TTY_SAFE}"
FADE_PID_FILE="/tmp/claude-semaphore-fade${TTY_SAFE}"

# Kill fade process
if [ -f "$FADE_PID_FILE" ]; then
  kill "$(cat "$FADE_PID_FILE" 2>/dev/null)" 2>/dev/null
  rm -f "$FADE_PID_FILE"
fi

# Restore original color
if [ -f "$ORIGINAL_FILE" ]; then
  IFS=', ' read -r r g b < "$ORIGINAL_FILE"
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
  rm -f "$ORIGINAL_FILE" "$STATE_FILE"
fi
