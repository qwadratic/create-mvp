#!/usr/bin/env bash
set -euo pipefail

# Get directory of this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORDFREQ="${DIR}/wordfreq.py"

echo "=== Running cli-integration self-tests ==="

# Test 1: Basic pipe and default top 5
echo -n "Test 1 (Basic pipe + default top 5): "
INPUT_1="Hello world! Hello. World... word freq! Word-freq."
EXPECTED_1='[{"word": "freq", "count": 2}, {"word": "hello", "count": 2}, {"word": "word", "count": 2}, {"word": "world", "count": 2}]'
ACTUAL_1=$(echo -n "$INPUT_1" | "$WORDFREQ")

# Compare with jq to be robust against spacing
if ! echo "$ACTUAL_1" | jq -e '. == '"$EXPECTED_1" > /dev/null; then
  echo "FAILED"
  echo "Expected: $EXPECTED_1"
  echo "Actual  : $ACTUAL_1"
  exit 1
fi
echo "PASSED"

# Test 2: Custom top flag (--top 2)
echo -n "Test 2 (Custom --top 2): "
INPUT_2="apple apple banana banana cherry"
EXPECTED_2='[{"word": "apple", "count": 2}, {"word": "banana", "count": 2}]'
ACTUAL_2=$(echo -n "$INPUT_2" | "$WORDFREQ" --top 2)

if ! echo "$ACTUAL_2" | jq -e '. == '"$EXPECTED_2" > /dev/null; then
  echo "FAILED"
  echo "Expected: $EXPECTED_2"
  echo "Actual  : $ACTUAL_2"
  exit 1
fi
echo "PASSED"

# Test 3: Tie breaking and sorting alphabetically
echo -n "Test 3 (Tie breaking alphabetical sorting): "
INPUT_3="zebra apple banana"
# Counts are all 1. Alphabetical sorting: apple, banana, zebra
EXPECTED_3='[{"word": "apple", "count": 1}, {"word": "banana", "count": 1}, {"word": "zebra", "count": 1}]'
ACTUAL_3=$(echo -n "$INPUT_3" | "$WORDFREQ" --top 3)

if ! echo "$ACTUAL_3" | jq -e '. == '"$EXPECTED_3" > /dev/null; then
  echo "FAILED"
  echo "Expected: $EXPECTED_3"
  echo "Actual  : $ACTUAL_3"
  exit 1
fi
echo "PASSED"

# Test 4: Top 0
echo -n "Test 4 (Top 0): "
INPUT_4="apple banana"
EXPECTED_4='[]'
ACTUAL_4=$(echo -n "$INPUT_4" | "$WORDFREQ" --top 0)

if ! echo "$ACTUAL_4" | jq -e '. == '"$EXPECTED_4" > /dev/null; then
  echo "FAILED"
  echo "Expected: $EXPECTED_4"
  echo "Actual  : $ACTUAL_4"
  exit 1
fi
echo "PASSED"

# Test 5: Empty input
echo -n "Test 5 (Empty input): "
INPUT_5=""
EXPECTED_5='[]'
ACTUAL_5=$(echo -n "$INPUT_5" | "$WORDFREQ")

if ! echo "$ACTUAL_5" | jq -e '. == '"$EXPECTED_5" > /dev/null; then
  echo "FAILED"
  echo "Expected: $EXPECTED_5"
  echo "Actual  : $ACTUAL_5"
  exit 1
fi
echo "PASSED"

# Test 6: Invalid --top option (negative integer)
echo -n "Test 6 (Invalid --top negative): "
if "$WORDFREQ" --top -1 < /dev/null 2> /dev/null; then
  echo "FAILED (Expected non-zero exit code)"
  exit 1
fi
echo "PASSED"

# Test 7: Invalid --top option (non-integer)
echo -n "Test 7 (Invalid --top non-integer): "
if "$WORDFREQ" --top abc < /dev/null 2> /dev/null; then
  echo "FAILED (Expected non-zero exit code)"
  exit 1
fi
echo "PASSED"

# Test 8: Unrecognized option
echo -n "Test 8 (Unrecognized option): "
if "$WORDFREQ" --unknown < /dev/null 2> /dev/null; then
  echo "FAILED (Expected non-zero exit code)"
  exit 1
fi
echo "PASSED"

echo "All tests completed successfully!"
