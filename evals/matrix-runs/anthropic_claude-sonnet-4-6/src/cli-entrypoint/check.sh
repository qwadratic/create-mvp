#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
WORDFREQ="$DIR/wordfreq.py"

# Test 1: --top 1 on 'a a b' returns JSON array with 'a'
OUT=$(echo 'a a b' | python3 "$WORDFREQ" --top 1)
echo "$OUT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert isinstance(data, list), 'not a list'
assert len(data) == 1, f'expected 1 item, got {len(data)}'
assert data[0]['word'] == 'a', f'expected word=a, got {data[0][\"word\"]}'
assert data[0]['count'] == 2, f'expected count=2, got {data[0][\"count\"]}'
print('test1 ok')
"

# Test 2: default --top 5
OUT=$(echo 'one two three one two one' | python3 "$WORDFREQ")
echo "$OUT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert isinstance(data, list), 'not a list'
assert data[0]['word'] == 'one' and data[0]['count'] == 3
print('test2 ok')
"

# Test 3: empty input returns empty array
OUT=$(echo '' | python3 "$WORDFREQ")
echo "$OUT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data == [], f'expected [], got {data}'
print('test3 ok')
"

echo "all checks passed"
