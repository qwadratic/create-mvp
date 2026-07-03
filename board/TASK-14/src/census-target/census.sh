#!/usr/bin/env bash
# census.sh [plan.json] [dir] - count done components vs total from plan.
# done = stamp dir/build/<id>.done exists AND output dir/out/<id>/.built exists.
# prints "census: D/T done". exit 0 whether complete or not;
# non-zero only on census error (missing/unparsable plan.json).
set -euo pipefail

plan="${1:-plan.json}"
dir="${2:-.}"

[ -f "$plan" ] || { echo "census: plan not found: $plan" >&2; exit 1; }
ids=$(jq -r '.components[].id' "$plan" 2>/dev/null) \
  || { echo "census: unparsable plan: $plan" >&2; exit 1; }

total=0 done_n=0
for id in $ids; do
  total=$((total + 1))
  if [ -f "$dir/build/$id.done" ] && [ -f "$dir/out/$id/.built" ]; then
    done_n=$((done_n + 1))
  fi
done

echo "census: $done_n/$total done"
