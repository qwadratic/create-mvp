#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PROXY_DIR=../reverse-proxy

PIDS=()
TMP=$(mktemp -d)
cleanup() { { kill "${PIDS[@]}"; wait "${PIDS[@]}"; } 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

wait_port_line() { # file key
  local f=$1 key=$2 i
  for i in $(seq 1 50); do
    if grep -q "^$key=" "$f" 2>/dev/null; then
      grep "^$key=" "$f" | head -1 | cut -d= -f2; return 0
    fi
    sleep 0.1
  done
  echo "timeout waiting for $key in $f" >&2; return 1
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# 3 stub backends on free ports
BPORTS=(); BPIDS=()
for i in 1 2 3; do
  python3 "$PROXY_DIR/stub_backend.py" 0 >"$TMP/stub$i.log" 2>&1 &
  PIDS+=($!); BPIDS+=($!)
  BPORTS+=("$(wait_port_line "$TMP/stub$i.log" STUB_PORT)")
done

# proxy on free port
python3 "$PROXY_DIR/proxy.py" 0 "${BPORTS[@]}" >"$TMP/proxy.log" 2>&1 &
PIDS+=($!)
PPORT=$(wait_port_line "$TMP/proxy.log" PROXY_PORT)
URL="http://127.0.0.1:$PPORT"

# 1) balanced run -> exit 0
if ! python3 loadstand.py --requests 90 --concurrency 6 --url "$URL" >"$TMP/bal.log" 2>&1; then
  cat "$TMP/bal.log" >&2; fail "load stand exited nonzero on balanced backends"
fi
grep -q "BALANCE: OK" "$TMP/bal.log" || fail "missing BALANCE: OK"
grep -q "req/s=" "$TMP/bal.log" || fail "missing req/s output"
grep -q "p50=" "$TMP/bal.log" || fail "missing latency output"

# 2) forced skew: kill one backend (502s not counted -> its counter freezes)
kill "${BPIDS[2]}"; wait "${BPIDS[2]}" 2>/dev/null || true
if python3 loadstand.py --requests 90 --concurrency 6 --url "$URL" >"$TMP/skew.log" 2>&1; then
  cat "$TMP/skew.log" >&2; fail "load stand exited 0 on skewed backends"
fi
grep -q "BALANCE: FAIL" "$TMP/skew.log" || fail "missing BALANCE: FAIL on skew"

echo "OK: load-stand checks passed"
