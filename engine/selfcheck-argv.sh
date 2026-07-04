#!/bin/bash
# selfcheck: ENGINE_CLI preset argv rendering — dry (zero agent calls), diff vs
# committed golden. Catches accidental flag drift in engine/agent presets.
# Golden markers: <engine>=engine dir, <system.md>=prompts/system.md contents,
# <tmp>=codex -o tmpfile. Re-seed: rm fixtures/argv.golden && rerun && review diff.
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
GOLDEN="$DIR/fixtures/argv.golden"

render_all() {
  # neutralize env that leaks into argv (effort.json, session dir, passthrough flags)
  local B; B=$(mktemp -d)
  export B ENGINE_CLI_FLAGS='' PI_SESSION_DIR='' MODEL_SMALL='' MODEL_LARGE=''
  local cli tools
  for cli in claude pi codex gemini opencode; do
    for tools in no yes; do
      echo "== $cli tools=$tools"
      ENGINE_CLI=$cli "$DIR/agent" argv "$tools" PROMPT
    done
  done
  echo "== custom {prompt} slot"
  ENGINE_CLI=custom ENGINE_CLI_CUSTOM='mycli --oneshot {prompt}' "$DIR/agent" argv no PROMPT
  echo "== custom stdin (no slot)"
  ENGINE_CLI=custom ENGINE_CLI_CUSTOM='mycli --oneshot' "$DIR/agent" argv no PROMPT
}

out=$(render_all)
if [ ! -f "$GOLDEN" ]; then
  printf '%s\n' "$out" > "$GOLDEN"
  echo "NOTE: golden seeded at $GOLDEN — review + commit" >&2
  exit 0
fi
diff -u "$GOLDEN" <(printf '%s\n' "$out")
echo "PASS: preset argv matches golden ($(grep -c '^==' "$GOLDEN") cases)"
