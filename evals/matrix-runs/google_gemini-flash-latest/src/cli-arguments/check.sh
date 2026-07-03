#!/bin/bash
set -e

# Change directory to the component directory to ensure relative imports work
cd "$(dirname "$0")"

# Execute unit tests
python3 test_cli_args.py
echo "All cli-arguments tests passed."
