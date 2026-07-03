#!/bin/bash
set -e

# Test word-counter component
# Non-interactive self-test, exits 0 on success

COUNTER="$(cd "$(dirname "$0")" && pwd)/counter.py"

# Test 1: Basic word counting
echo "Test 1: Basic word counting"
output=$(echo "Hello World hello WORLD" | python3 "$COUNTER")
expected='{"hello": 2, "world": 2}'
if [ "$output" = "$expected" ]; then
  echo "✓ Test 1 passed"
else
  echo "✗ Test 1 failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi

# Test 2: Non-letter splitting
echo "Test 2: Non-letter splitting"
output=$(echo "hello-world! test_case" | python3 "$COUNTER")
expected='{"case": 1, "hello": 1, "test": 1, "world": 1}'
if [ "$output" = "$expected" ]; then
  echo "✓ Test 2 passed"
else
  echo "✗ Test 2 failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi

# Test 3: Empty input
echo "Test 3: Empty input"
output=$(echo "" | python3 "$COUNTER")
expected='{}'
if [ "$output" = "$expected" ]; then
  echo "✓ Test 3 passed"
else
  echo "✗ Test 3 failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi

# Test 4: Only non-letters
echo "Test 4: Only non-letters"
output=$(echo "!@#$%^&*()" | python3 "$COUNTER")
expected='{}'
if [ "$output" = "$expected" ]; then
  echo "✓ Test 4 passed"
else
  echo "✗ Test 4 failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi

# Test 5: Numbers as delimiters
echo "Test 5: Numbers as delimiters"
output=$(echo "word123test456abc" | python3 "$COUNTER")
expected='{"abc": 1, "test": 1, "word": 1}'
if [ "$output" = "$expected" ]; then
  echo "✓ Test 5 passed"
else
  echo "✗ Test 5 failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi

echo ""
echo "All tests passed!"
exit 0
