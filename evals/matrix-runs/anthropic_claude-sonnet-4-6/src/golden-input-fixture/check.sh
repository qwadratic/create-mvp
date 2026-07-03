#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$DIR/tests/input.txt"

# file exists
[ -f "$INPUT" ] || { echo "FAIL: $INPUT missing"; exit 1; }

# non-empty
[ -s "$INPUT" ] || { echo "FAIL: $INPUT is empty"; exit 1; }

echo "OK: tests/input.txt exists and is non-empty"
