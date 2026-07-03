#!/usr/bin/env bash
# generate.sh <plan.json> - emit components.mk on stdout.
# One stamp target build/<id>.done per component, prereqs = dep stamps.
set -euo pipefail
plan="${1:?usage: generate.sh <plan.json>}"
[ -f "$plan" ] || { echo "generate: no such file: $plan" >&2; exit 1; }
jq -r -f "$(dirname "$0")/components.jq" "$plan"
