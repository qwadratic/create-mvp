#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
EXPECTED="$DIR/tests/expected.json"

# valid JSON check
jq '.' "$EXPECTED" > /dev/null

echo "OK: tests/expected.json is valid JSON"
