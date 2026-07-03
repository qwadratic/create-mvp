#!/usr/bin/env bash
# A6 golden screenshot eval: boot stack on free ports via run-harness,
# snap / at 1280x800, structural pixel asserts, then evalshot vs golden.png
# (golden bootstrapped on first run — review + commit it).
set -euo pipefail
cd "$(dirname "$0")"
EVALS=../../../../evals   # ../../evals relative to demo root

TMP=$(mktemp -d)
HARNESS_PID=""
cleanup() { [ -n "$HARNESS_PID" ] && kill "$HARNESS_PID" 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
fail() { echo "FAIL: $1" >&2; exit 1; }

command -v ffmpeg >/dev/null || fail "ffmpeg required (evalshot/checkpixels)"

# free ports (bind-port-0 trick, 4 at once to avoid self-collision)
read -r B1 B2 B3 PROXY < <(python3 -c '
import socket
socks = [socket.socket() for _ in range(4)]
for s in socks: s.bind(("127.0.0.1", 0))
print(*[s.getsockname()[1] for s in socks])')

B1=$B1 B2=$B2 B3=$B3 PROXY_PORT=$PROXY ../run-harness/run.sh >/dev/null 2>&1 &
HARNESS_PID=$!

URL="http://127.0.0.1:$PROXY/"
DEADLINE=$((SECONDS + 10))
until curl -fsS "${URL}api/health" >/dev/null 2>&1; do
  [ $SECONDS -ge $DEADLINE ] && fail "stack not healthy in 10s"
  sleep 0.2
done

# snap + structural pixel check; retry (JS timeline fetch can race the shot)
SHOT="$TMP/shot.png"
OK=0
for i in 1 2 3; do
  "$EVALS/snap" "$URL" "$SHOT" 1280 800
  if python3 checkpixels.py "$SHOT"; then OK=1; break; fi
  echo "retry $i: structural check failed, re-snapping" >&2
  sleep 0.5
done
[ "$OK" = 1 ] || { cp "$SHOT" ./last-fail.png; fail "structural pixel check (see last-fail.png)"; }

# golden compare (bootstraps golden.png on first run)
"$EVALS/evalshot" "$SHOT" ./golden.png || { cp "$SHOT" ./last-fail.png; fail "evalshot vs golden.png (see last-fail.png / shot.diff.png)"; }

echo "A6 OK: visual eval passed"
