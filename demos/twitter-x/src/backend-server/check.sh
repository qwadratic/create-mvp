#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d)
PIDS=()
cleanup() { kill "${PIDS[@]}" 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

DB="$TMP/tw.db"
python3 ../db-seed/seed.py "$DB" >/dev/null

python3 server.py 0 "$DB" >"$TMP/srv.log" 2>&1 &
PIDS+=($!)

PORT=""
for i in $(seq 1 50); do
  PORT=$(grep '^BACKEND_PORT=' "$TMP/srv.log" 2>/dev/null | head -1 | cut -d= -f2) && [ -n "$PORT" ] && break
  sleep 0.1
done
[ -n "$PORT" ] || fail "server did not start"
URL="http://127.0.0.1:$PORT"

# health
OUT=$(curl -fsS "$URL/api/health")
echo "$OUT" | grep -q '"ok": true' || fail "health ok missing"
echo "$OUT" | grep -q "\"port\": $PORT" || fail "health port mismatch"

# timeline: schema + newest-first (seed ids 1..8 -> first id 8)
OUT=$(curl -fsS "$URL/api/timeline")
echo "$OUT" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ts=d["tweets"]
assert len(ts)>=8, "expected >=8 seeded tweets"
ids=[t["id"] for t in ts]
assert ids==sorted(ids,reverse=True), "not newest-first"
need={"id","handle","name","avatar_color","text","ts","replies","retweets","likes"}
for t in ts: assert set(t)==need, f"schema mismatch: {set(t)}"
' || fail "timeline schema/order"

# POST -> 201 + tweet JSON
CODE=$(curl -s -o "$TMP/post.json" -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -d '{"text":"hello from check"}' "$URL/api/tweets")
[ "$CODE" = 201 ] || fail "POST expected 201, got $CODE"
grep -q '"text": "hello from check"' "$TMP/post.json" || fail "created tweet JSON wrong"

# new tweet on top of timeline
curl -fsS "$URL/api/timeline" | python3 -c '
import json,sys
assert json.load(sys.stdin)["tweets"][0]["text"]=="hello from check"
' || fail "posted tweet not first in timeline"

# 400 cases: missing, empty, >280
for BODY in '{}' '{"text":""}' '{"text":"'"$(printf 'x%.0s' $(seq 281))"'"}'; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -d "$BODY" "$URL/api/tweets")
  [ "$CODE" = 400 ] || fail "expected 400 for $BODY, got $CODE"
done

# GET / serves HTML
CODE=$(curl -s -o "$TMP/index.html" -w '%{http_code}' "$URL/")
[ "$CODE" = 200 ] || fail "GET / expected 200, got $CODE"
grep -qi '<html' "$TMP/index.html" || fail "GET / not HTML"

echo "OK: backend-server checks passed"
