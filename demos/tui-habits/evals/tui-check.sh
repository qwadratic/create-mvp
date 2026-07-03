#!/usr/bin/env bash
# tui-check.sh — tmux capture-pane text-golden gate for tui-habits.
# Recipe: makefile-lab/evals/TUI.md (80x24 grid, poll-not-sleep, strip trailing ws).
# Frames: 01 --render table | 02 curses TUI initial | 03 TUI after j+space toggle.
# UPDATE_GOLDEN=1 regenerates goldens. Every captured frame saved to shots/.
# Fixture dates are relative to today -> streak numbers stable across days.
set -euo pipefail
cd "$(dirname "$0")/.."
G=evals/goldens; mkdir -p "$G" shots
S="tuihab-$$"
TMP=$(mktemp)
trap 'tmux kill-session -t "$S" 2>/dev/null || true; rm -f "$TMP"' EXIT

python3 - "$TMP" <<'EOF'
import json, sys
from datetime import date, timedelta
t = date.today()
d = lambda n: (t - timedelta(days=n)).isoformat()
json.dump({
    "exercise": [d(2), d(1), d(0)],        # done today, cur 3 best 3
    "read":     [d(4), d(3), d(2), d(1)],  # yesterday-grace, cur 4 best 4
    "meditate": [],                         # cur 0 best 0
}, open(sys.argv[1], "w"))
EOF

capture() { tmux capture-pane -pt "$S" | sed 's/[[:space:]]*$//'; }
wait_for() {  # wait_for <grep-pattern>
  for _ in $(seq 1 50); do capture | grep -q "$1" && return 0; sleep 0.1; done
  echo "FAIL: timeout waiting for '$1'; last frame:" >&2; capture >&2; return 1
}
gate() {  # gate <frame-name>  (stdin = actual frame)
  local a="shots/$1.txt"
  cat > "$a"
  if [ "${UPDATE_GOLDEN:-}" = 1 ]; then cp "$a" "$G/$1.txt"; echo "golden updated: $1"; return 0; fi
  diff -u "$G/$1.txt" "$a" && echo "PASS: $1"
}

# frame 01: non-interactive --render (capture-pane -p strips ANSI color)
tmux new-session -d -s "$S" -x 80 -y 24 \
  "HABITS_FILE=$TMP python3 src/render-view/view.py --render; sleep 30"
wait_for 'exercise'
capture | gate 01-render
tmux kill-session -t "$S"

# frame 02: curses TUI initial screen ('read' row drawn last -> ready marker)
tmux new-session -d -s "$S" -x 80 -y 24 "HABITS_FILE=$TMP python3 src/tui-loop/tui.py"
wait_for '\[ \] read'
capture | gate 02-tui-initial

# frame 03: j (select meditate) + space (mark done today)
tmux send-keys -t "$S" j
sleep 0.2
tmux send-keys -t "$S" Space
wait_for '\[x\] meditate'
capture | gate 03-tui-toggle
tmux send-keys -t "$S" q
