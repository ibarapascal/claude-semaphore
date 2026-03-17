#!/bin/bash
# Restore terminal background color after Claude exits (called by shell wrapper)
MY_TTY=$(tty 2>/dev/null)
[ -z "$MY_TTY" ] || [ "$MY_TTY" = "not a tty" ] && exit 0

TTY_SAFE=$(echo "$MY_TTY" | tr '/' '_')
STATE_FILE="/tmp/claude-semaphore-state${TTY_SAFE}"
FADE_PID_FILE="/tmp/claude-semaphore-fade${TTY_SAFE}"

# Kill fade process
if [ -f "$FADE_PID_FILE" ]; then
  kill "$(cat "$FADE_PID_FILE" 2>/dev/null)" 2>/dev/null
  rm -f "$FADE_PID_FILE"
fi

# Reset to Terminal.app default dark gray via OSC 11
# Avoids OSC 111 which crashes Terminal.app
printf '\033]11;rgb:%04x/%04x/%04x\007' 5866 5866 5866 > "$MY_TTY" 2>/dev/null
rm -f "$STATE_FILE"
