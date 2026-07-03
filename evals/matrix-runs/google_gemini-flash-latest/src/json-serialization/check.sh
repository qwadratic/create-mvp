#!/bin/bash
set -euo pipefail

# Find directory where check.sh is located
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run python unit tests
python3 "${DIR}/test_serializer.py"
echo "All json-serialization tests passed."
