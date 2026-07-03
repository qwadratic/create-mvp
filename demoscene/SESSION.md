# session.cast / session-trace.jsonl — forth-tool evolution session

Live pi session where the agent **evolves `demos/forth-forth` using only the
`forth` tool** (persistent stage0 VM, see `forth-tool/`). No bash, no edit, no
write — file changes happen through forth words (`s" ..." fwrite`, `load`,
`fread`).

## What the agent built

New golden test: 16-row Sierpinski triangle.

- `demos/forth-forth/src/tests/sierpinski.fs` — quote-free forth (an `s"`
  payload cannot contain `"`, so no `." ..."` strings; pure numbers / emit /
  loops). Lucas' theorem via `mod`/`/` in a `begin/until` loop — the dialect
  has no bitwise words.
- `demos/forth-forth/src/tests/golden/sierpinski.out` — 152 bytes, written by
  the agent via `fwrite`, verified in-session with `load` + `fread`/`h.`.

Landed **first try** (no retry needed). 11 `forth` tool calls, zero other
tools (allowlist `--tools forth` held).

## Recording setup

```sh
tmux new-session -x 120 -y 36 \
  'asciinema rec session.cast -c "pi -ne -nc --no-skills --no-prompt-templates \
     --tools forth -e demoscene/forth-tool/index.ts --session-dir <tmp> \
     --thinking medium -n forth-evolution"'
# prompt injected via tmux load-buffer/paste-buffer; /exit sent after
# the session JSONL showed a final assistant stopReason=stop
```

- `session.cast` — asciinema v3, full TUI session, cwd `demos/forth-forth`.
- `session-trace.jsonl` — the raw pi session file (v3 JSONL, see pi
  `docs/session-format.md`): every tool call's forth code + results,
  machine-readable input for ATTN-SPEC session-mode frames.
- Quirk: the multi-line prompt pasted as several queued messages (pi steering
  queue); the agent consumed all chunks — visible in the trace as multiple
  user entries.

## Gate (post-session, external)

- `src/gate/check.sh` extended to include `sierpinski` (edit done **outside**
  the session: the script contains `"` chars, unwritable through the forth
  tool's `s"` payloads — the one integration step the tool cannot express).
- Results: interpreted == compiled == golden for all 4 tests; stage1 smoke OK;
  pinned goldens OK; selfhost still ACHIEVED; `wfcheck: PASS 32/32 (score 1)`.

## Honesty note

`session-trace.jsonl` is raw session data. Any "attention" rendering derived
from it (per `ATTN-SPEC.md`) is an **interpretive proxy — not model
internals**: weights come from forth grammar structure, token categories, and
session recency, never from the hosted model, and every rendered frame must
carry that label.
