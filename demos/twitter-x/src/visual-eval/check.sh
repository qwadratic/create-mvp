#!/usr/bin/env bash
# non-interactive self-test: full capture + compare (<60s), cleanup via eval.sh trap
set -euo pipefail
cd "$(dirname "$0")"
exec ./eval.sh
