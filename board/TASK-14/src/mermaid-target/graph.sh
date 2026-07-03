#!/usr/bin/env bash
# graph.sh <plan.json> - emit mermaid 'graph TD' on stdout.
set -euo pipefail
plan="${1:?usage: graph.sh <plan.json>}"
[ -f "$plan" ] || { echo "graph: no such file: $plan" >&2; exit 1; }
jq -r -f "$(dirname "$0")/graph.jq" "$plan"
