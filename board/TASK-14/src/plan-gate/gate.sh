#!/usr/bin/env bash
# gate.sh <plan.json> - validate plan schema. Exit non-zero with message on violation.
set -euo pipefail

plan="${1:?usage: gate.sh <plan.json>}"

[ -f "$plan" ] || { echo "gate: no such file: $plan" >&2; exit 1; }
jq -e . "$plan" >/dev/null 2>&1 || { echo "gate: invalid JSON: $plan" >&2; exit 1; }

err=$(jq -r '
  if (.components|type) != "array" then "components is not an array"
  elif (.components|length) == 0 then "components is empty"
  else
    (.components|map(.id)) as $ids |
    ( [.components[].id | select(test("^[a-z0-9]+(-[a-z0-9]+)*$")|not)] ) as $bad |
    ( [.components[] | .id as $i | (.deps // [])[] | select(. as $d | $ids|index($d)|not) | "\($i) -> \(.)"] ) as $dangling |
    if ($bad|length) > 0 then "bad id(s): \($bad|join(", "))"
    elif ($dangling|length) > 0 then "dangling dep(s): \($dangling|join(", "))"
    else empty end
  end
' "$plan")

if [ -n "$err" ]; then
  echo "gate: $err" >&2
  exit 1
fi
echo "gate: OK ($plan)"
