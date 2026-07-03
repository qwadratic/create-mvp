#!/usr/bin/env bash
# self-test for stub-agent. exits 0 on success.
set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

agent="$PWD/agent.sh"
cd "$tmp"

echo "example goal" > goal.md

# plan: valid JSON, non-empty components, deterministic
"$agent" plan goal.md > p1.json
jq -e '.components | type == "array" and length > 0' p1.json > /dev/null
"$agent" plan goal.md > p2.json
cmp -s p1.json p2.json

# plan: missing goal file fails
! "$agent" plan nope.md 2>/dev/null

# build: creates expected files, deterministic, executable
"$agent" build core
[ -x out/core/main.sh ]
[ -f out/core/.built ]
grep -q 'component core' out/core/main.sh
grep -q 'built core' out/core/.built
h1="$(cat out/core/main.sh)"
"$agent" build core
[ "$h1" = "$(cat out/core/main.sh)" ]

# build: bad id fails
! "$agent" build 'Bad_ID' 2>/dev/null

# usage error
! "$agent" 2>/dev/null

echo "stub-agent check OK"
