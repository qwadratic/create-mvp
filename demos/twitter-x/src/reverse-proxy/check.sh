#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PIDS=()
cleanup() { kill "${PIDS[@]}" 2>/dev/null || true; wait 2>/dev/null || true; }
trap cleanup EXIT

TMP=$(mktemp -d)
trap 'cleanup; rm -rf "$TMP"' EXIT

wait_port_line() { # file key -> echoes value
  local f=$1 key=$2 i
  for i in $(seq 1 50); do
    if grep -q "^$key=" "$f" 2>/dev/null; then
      grep "^$key=" "$f" | head -1 | cut -d= -f2
      return 0
    fi
    sleep 0.1
  done
  echo "timeout waiting for $key in $f" >&2
  return 1
}

# 3 stub backends on free ports (bind port 0)
BPORTS=()
BPIDS=()
for i in 1 2 3; do
  python3 stub_backend.py 0 >"$TMP/stub$i.log" 2>&1 &
  PIDS+=($!); BPIDS+=($!)
  BPORTS+=("$(wait_port_line "$TMP/stub$i.log" STUB_PORT)")
done

# proxy on free port
python3 proxy.py 0 "${BPORTS[@]}" >"$TMP/proxy.log" 2>&1 &
PIDS+=($!)
PPORT=$(wait_port_line "$TMP/proxy.log" PROXY_PORT)
URL="http://127.0.0.1:$PPORT"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1) rotation + X-Backend header over 3 requests
SEEN=""
for i in 1 2 3; do
  H=$(curl -fsS -D - -o "$TMP/body$i" "$URL/api/health?x=$i")
  XB=$(echo "$H" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-backend"{print $2}')
  [ -n "$XB" ] || fail "missing X-Backend"
  echo "$SEEN" | grep -qw "$XB" && fail "backend $XB repeated within first 3 requests"
  SEEN="$SEEN $XB"
  # body verbatim from stub, port matches header
  grep -q "\"port\": $XB" "$TMP/body$i" || fail "body port != X-Backend"
done
for p in "${BPORTS[@]}"; do
  echo "$SEEN" | grep -qw "$p" || fail "backend $p never hit"
done

# 2) method/path/query/body forwarding
OUT=$(curl -fsS -X POST -d 'hello=world' "$URL/api/tweets?q=1")
echo "$OUT" | grep -q '"method": "POST"' || fail "method not forwarded"
echo "$OUT" | grep -q '"path": "/api/tweets?q=1"' || fail "path/query not forwarded"
echo "$OUT" | grep -q '"body": "hello=world"' || fail "body not forwarded"

# 3) /lb-stats answered locally: total=4, counts 2/1/1 in rotation order
STATS=$(curl -fsS "$URL/lb-stats")
echo "$STATS" | grep -q '"total": 4' || fail "lb-stats total != 4: $STATS"
echo "$STATS" | grep -q "{\"port\": ${BPORTS[0]}, \"requests\": 2}" || fail "backend0 count wrong: $STATS"
echo "$STATS" | grep -q "{\"port\": ${BPORTS[1]}, \"requests\": 1}" || fail "backend1 count wrong: $STATS"
echo "$STATS" | grep -q "{\"port\": ${BPORTS[2]}, \"requests\": 1}" || fail "backend2 count wrong: $STATS"

# 4) dead backend -> 502 JSON, counter not incremented
kill "${BPIDS[1]}"; wait "${BPIDS[1]}" 2>/dev/null || true
GOT502=0
for i in 1 2 3; do
  CODE=$(curl -s -o "$TMP/dead$i" -w '%{http_code}' "$URL/api/health")
  if [ "$CODE" = 502 ]; then
    GOT502=1
    grep -q '"error"' "$TMP/dead$i" || fail "502 body not JSON error"
  fi
done
[ "$GOT502" = 1 ] || fail "no 502 seen after killing backend"
STATS2=$(curl -fsS "$URL/lb-stats")
echo "$STATS2" | grep -q "{\"port\": ${BPORTS[1]}, \"requests\": 1}" || fail "dead backend counter incremented: $STATS2"
echo "$STATS2" | grep -q '"total": 6' || fail "total should be 6 (2 live requests): $STATS2"

echo "OK: reverse-proxy checks passed"
