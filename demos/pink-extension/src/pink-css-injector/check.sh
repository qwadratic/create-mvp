#!/bin/sh
set -e
cd "$(dirname "$0")"
node --check content.js
node test.js
