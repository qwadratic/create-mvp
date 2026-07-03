#!/bin/bash
# selfcheck: effort classifier — 3 fixture goals (one per tier), schema-valid,
# tiers must come back ordered vague → standard → prd. Real LLM calls (cheap).
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
SCHEMA='(.tier|IN("vague","standard","prd")) and (.fanout|test("^[0-9]+-[0-9]+$")) and (.review_depth|IN("smoke","standard","full")) and (.model_hint|IN("small","default","large")) and (.thinking|IN("off","low","medium","high"))'

got=()
for f in vague standard prd; do
  out=$("$DIR/agent" classify "$DIR/fixtures/goal-$f.md")
  echo "$out" | jq -e "$SCHEMA" > /dev/null || { echo "FAIL schema ($f): $out" >&2; exit 1; }
  got+=("$(echo "$out" | jq -r .tier)")
  echo "goal-$f.md -> $out"
done
[ "${got[*]}" = "vague standard prd" ] || { echo "FAIL order: got '${got[*]}'" >&2; exit 1; }
echo "PASS: tiers ordered (${got[*]})"
