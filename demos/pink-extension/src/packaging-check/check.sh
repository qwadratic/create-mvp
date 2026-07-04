#!/bin/sh
set -e
cd "$(dirname "$0")"

# run sibling component self-tests
sh ../pink-css-injector/check.sh
sh ../extension-manifest/check.sh

# assemble extension tree and validate
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp ../extension-manifest/manifest.json ../pink-css-injector/content.js "$STAGE"/
node check.js "$STAGE"

# negative self-test: missing referenced file must fail
rm "$STAGE/content.js"
if node check.js "$STAGE" 2>/dev/null; then
  echo "FAIL: expected nonzero exit on missing file"
  exit 1
fi
echo "OK: packaging-check self-test passed"
