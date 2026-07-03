#!/usr/bin/env bash
# twitter-x run harness. Usage: run.sh [--check]
# Env overrides: B1 B2 B3 (backend ports), PROXY_PORT, DB_PATH.
set -euo pipefail
cd "$(dirname "$0")"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

B1=${B1:-9101}; B2=${B2:-9102}; B3=${B3:-9103}
PROXY=${PROXY_PORT:-8080}
TMP=$(mktemp -d)
DB=${DB_PATH:-$TMP/twitter.db}
UI=$(cd ../ui-page && pwd)/index.html
PIDS=()
cleanup() { kill "${PIDS[@]}" 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
fail() { echo "FAIL: $1" >&2; exit 1; }

python3 ../db-seed/seed.py "$DB" >/dev/null

for P in "$B1" "$B2" "$B3"; do
  python3 ../backend-server/server.py "$P" "$DB" "$UI" >/dev/null 2>&1 &
  PIDS+=($!)
done
python3 ../reverse-proxy/proxy.py "$PROXY" "$B1" "$B2" "$B3" >/dev/null 2>&1 &
PIDS+=($!)

# wait all 4 healthy within 5s (direct health -> proxy counters untouched;
# /lb-stats answered by proxy itself -> also untouched)
DEADLINE=$((SECONDS + 5))
for P in "$B1" "$B2" "$B3"; do
  until curl -fsS "http://127.0.0.1:$P/api/health" >/dev/null 2>&1; do
    [ $SECONDS -ge $DEADLINE ] && fail "backend $P not healthy in 5s"
    sleep 0.1
  done
done
until curl -fsS "http://127.0.0.1:$PROXY/lb-stats" >/dev/null 2>&1; do
  [ $SECONDS -ge $DEADLINE ] && fail "proxy not healthy in 5s"
  sleep 0.1
done

PURL="http://127.0.0.1:$PROXY"

if [ "$CHECK" = 0 ]; then
  echo "proxy:    $PURL"
  echo "backends: http://127.0.0.1:$B1 http://127.0.0.1:$B2 http://127.0.0.1:$B3"
  echo "ui:       $PURL/"
  echo "Ctrl-C to stop."
  wait
  exit 0
fi

### --check: A1-A5 ###

# A1: 3 consecutive health calls via proxy hit 3 different backend ports
PORTS=""
for i in 1 2 3; do
  P=$(curl -fsS "$PURL/api/health" | python3 -c 'import json,sys;print(json.load(sys.stdin)["port"])')
  PORTS="$PORTS $P"
done
N=$(echo "$PORTS" | tr ' ' '\n' | sort -u | grep -c . )
[ "$N" = 3 ] || fail "A1 round-robin: got ports$PORTS"
echo "A1 OK: round-robin ports$PORTS"

# A2: timeline schema + newest-first via proxy
curl -fsS "$PURL/api/timeline" | python3 -c '
import json, sys
ts = json.load(sys.stdin)["tweets"]
assert len(ts) >= 8, "expected >=8 seeded tweets"
ids = [t["id"] for t in ts]
assert ids == sorted(ids, reverse=True), "not newest-first"
need = {"id","handle","name","avatar_color","text","ts","replies","retweets","likes"}
for t in ts:
    assert set(t) == need, f"schema mismatch: {set(t)}"
' || fail "A2 timeline schema/order"
echo "A2 OK: timeline schema newest-first"

# A3: POST via proxy visible from a DIFFERENT backend
TEXT="harness-check-$$-$RANDOM"
POST_BE=$(curl -fsS -D - -o /dev/null -X POST -H 'Content-Type: application/json' \
  -d "{\"text\":\"$TEXT\"}" "$PURL/api/tweets" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-backend"{print $2}')
[ -n "$POST_BE" ] || fail "A3 no X-Backend on POST"
FOUND=0
for i in 1 2 3; do
  HDRS="$TMP/h$i"; BODY="$TMP/b$i"
  curl -fsS -D "$HDRS" -o "$BODY" "$PURL/api/timeline"
  GET_BE=$(tr -d '\r' < "$HDRS" | awk -F': ' 'tolower($1)=="x-backend"{print $2}')
  if [ "$GET_BE" != "$POST_BE" ] && grep -q "$TEXT" "$BODY"; then FOUND=1; break; fi
done
[ "$FOUND" = 1 ] || fail "A3 tweet posted via backend $POST_BE not visible from another backend"
echo "A3 OK: WAL shared state (posted via $POST_BE, read via $GET_BE)"

# A4a: /lb-stats total tracks forwarded request count exactly
T0=$(curl -fsS "$PURL/lb-stats" | python3 -c 'import json,sys;print(json.load(sys.stdin)["total"])')
for i in $(seq 1 9); do curl -fsS "$PURL/api/timeline" >/dev/null; done
T1=$(curl -fsS "$PURL/lb-stats" | python3 -c 'import json,sys;print(json.load(sys.stdin)["total"])')
[ $((T1 - T0)) = 9 ] || fail "A4 lb-stats total delta $((T1 - T0)) != 9"
# A4b: load stand -> every backend within 10% of mean (loadstand exits nonzero otherwise)
python3 ../load-stand/loadstand.py --requests 300 --concurrency 10 --url "$PURL" \
  || fail "A4 load-stand balance"
echo "A4 OK: lb-stats total + balance"

# A5: UI via proxy is self-contained + has X layout markers
curl -fsS "$PURL/" > "$TMP/ui.html"
grep -qE 'https?://' "$TMP/ui.html" && fail "A5 UI references external URLs"
for M in nav-rail compose tweet; do
  grep -q "class=\"$M" "$TMP/ui.html" || fail "A5 UI missing marker: $M"
done
echo "A5 OK: self-contained UI with nav rail/compose/cards"

echo "ALL CHECKS PASSED"
