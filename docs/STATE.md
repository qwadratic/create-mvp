# STATE — repo snapshot for the iterate-until-viral loop

Last updated: 2026-07-03 @ post-nested-decomposition fixer pass (`8e949f5`).
Working tree clean, all selftests re-run green at write time
(`wfcheck-selftest` 28/28 incl. nested breaks, `nested-selftest` full matrix,
`apieval-selftest` incl. TOON round-trip, `selfcheck-classify` tier ordering).
Link audit across README + docs: 0 dead links.

## What exists

| area | artifact | status |
|---|---|---|
| Engine core | [`engine/build.mk`](../engine/build.mk) (~120 lines): classify → plan → jq-generated `components.mk` (re-include restart) → per-component agents + `check.sh` gates → review gate; `.DELETE_ON_ERROR` resume | live-verified cold: fresh `/tmp` project, 2-line Makefile, full pipeline + rerun no-op |
| Nested decomposition | [`docs/rfc-nested.md`](rfc-nested.md): composite components → [`engine/subtree`](../engine/subtree) scaffold + recursive `$(MAKE) -C`; deterministic bounds (MAXDEPTH 3, MAXTIER clamp, MAXFANOUT 8) in jq/make; progress/graph/wfcheck recurse, flat runs byte-identical | mock-first zero-LLM e2e (`engine/fixtures/nested-selftest.sh`) + live real-PRD run (site-forge) |
| Board integration | [`engine/board.mk`](../engine/board.mk): Backlog.md = default work queue; `board` / `board-next` / `board-task`; failed gate leaves task In Progress | verified e2e — TASK-14 pulled → Done via CLI |
| Self-host proof | [`board/TASK-14/`](../board/TASK-14/) — engine built itself from the board, 7 components, wfcheck 32/32 | committed run artifacts |
| Agent adapter | [`engine/agent`](../engine/agent): roles plan/build/review; `RUNTIME=cli\|sdk`, `ENGINE_CLI=pi\|claude`, `ENGINE_CLI_FLAGS` passthrough; per-unit `effort.json` model routing | pi-cli + sdk live-verified; claude reaches auth boundary only (TASK-16) |
| Style injection | [`engine/prompts/system.md`](../engine/prompts/system.md) (caveman+ponytail) injected at the single `run()` chokepoint, both runtimes | judge-verified, no bypass path |
| Evals | [`evals/`](../evals/): `snap` (~0.2s/shot), `evalshot` (SSIM golden), `apieval` (jq+TOON golden), `wfcheck` (whole-run grade), `matrix` (multi-model); TUI tmux-golden recipe | selftests green; apieval wired live in twitter-x `run.sh --check` |
| Effort tiers | classify gate: vague/standard/prd → fan-out, review depth, model hint, thinking | [`docs/effort-and-hitl.md`](effort-and-hitl.md) |
| HITL design | approval-file gates (`build/approvals/<step>.ok`, timestamp staleness re-opens) | designed + documented, NOT wired by default (TASK-2) |
| pi extension | [`extension/index.ts`](../extension/index.ts): built-ins disabled, single `agentmake_demo` tool, `/demo` command, bundled `agentic-makefile` skill | judge-verified present |
| Dogfood narrative | [`docs/dogfood-autopsy.md`](dogfood-autopsy.md) + committed mess dirs (`dogfood-*/`) + README "Eating the dogfood" | STEERING arc complete |
| Secret protection | psst + gitleaks `[[allowlists]]`, tracked `.githooks/pre-commit` | live-tested: staged AKIA/ghp tokens → commit blocked |
| Media | `media/`: engine-run cast+gif, per-demo gifs, gallery.png | real, unedited runs |
| Backlog | 13 To Do / 3 Done — the roadmap IS the board, any item is one `make board-next` away | `backlog board` |

## Demos (all built by the engine from the committed goal file, unedited)

| demo | tier | wfcheck | judge | wow |
|---|---|---|---|---|
| [game-of-life](../demos/game-of-life/) | vague (33 B) | 16/16 | — | — |
| [desk-dashboard](../demos/desk-dashboard/) | standard (94 B) | 24/24 | — | — |
| [tui-habits](../demos/tui-habits/) | standard (144 B) | 24/24 | — | — |
| [twitter-x](../demos/twitter-x/) | prd (5.4 KB) | 32/32 | 9.5/10 | **YES** — real X layout, LB split 0.6% deviation proven live, negative gate tested |
| [forth-forth](../demos/forth-forth/) | prd (5.8 KB) | 32/32 | 10/10 | **YES** — Forth compiler in Forth, self-hosting fixed point gen1==gen2, first run zero retries |
| [site-forge](../demos/site-forge/) | prd (6.2 KB) | 29/29 + subtree 24/24 | 9/10 (nested round) | **YES** — planner marked plugin subsystem composite on first call, subtree self-planned 5 components, zero gate failures |

(— = per-demo wow verdict not in retained judge output; wfcheck 1.0 on all six.)

## Judge scores (final re-judge round)

- **Clone-cold overall: 9/10.** All previously-flagged STEERING criticals resolved. 2-line include claim verified in `/tmp`, secret hook blocks, selftests pass.
- **Docs re-judge:** 0 dead links; every wfcheck claim matches committed `wfscore.json` exactly; comprehension test (DAG restart, `.DELETE_ON_ERROR`, HITL flip) passed.
- **Demos-wow:** all 5 wfchecks re-run live, PASS 1.0. twitter-x 9.5, forth-forth 10.
- **Requirements:** jq+TOON evals PRESENT+used; caveman+ponytail in all agent calls both runtimes PRESENT; RUNTIME cli/sdk PRESENT (claude environmental caveat); pi extension PRESENT.

## Multi-model matrix ([full report](../evals/matrix-results.md))

| model | wfcheck | score | make | wall (s) | components | tokens | cost (USD) |
|---|---|---|---|---|---|---|---|
| anthropic/claude-haiku-4-5 | 19/20 | 0.95 | exit 2 | 265 | 4 | 547067 | 0.2676 |
| anthropic/claude-sonnet-4-6 | 28/32 | 0.88 | exit 2 | 127 | 7 | 211574 | 0.2785 |
| google/gemini-flash-latest | 28/28 | 1 | ok | 321 | 6 | 1247976 | 1.9685 |

`make` ≠ ok = a gate rejected honestly. Single-run, parallel on one host — trend, not benchmark.

## Known ceilings (honest, also in README "Honest limitations")

1. **No feedback on retry** — failed gate deletes artifact, rerun fires a fresh agent with no memory. Biggest quality ceiling. → TASK-10
2. **HITL designed, not default** — `.ok` layer is a one-line jq change away. → TASK-2
3. **Copy-based sibling integration** — nested decomposition landed (TASK-11 Done: depth ≤ 3, fan-out ≤ 8/level, tier clamp), but siblings integrate by copying files per description contract; no shared artifact store, one real-PRD composite datapoint (site-forge).
4. **Tool-less planner roleplay** — hallucinated tool-call transcripts before JSON (observed on self-host, gate rejected twice, retries cost money). → TASK-15
5. **Self-seeded goldens** — evalshot/apieval bootstrap golden from current output (loud NOTE, human must eyeball). twitter-x ssim=1.0 golden is self-bootstrapped; independent `checkpixels` asserts keep it honest. → TASK-4
6. **claude runtime unverified e2e** — plumbing complete, blocked on creds (environmental). → TASK-16
7. **Nondeterministic plans** — gates hold, but `build/` not bit-reproducible; matrix numbers single-run.
8. **snap boots a browser per shot** (~190 ms) — CDP-pool upgrade specced in [BENCH.md](../evals/docs/BENCH.md), not built. → TASK-6
9. **Cost** — small-CLI matrix goal $0.27–$1.97/run; PRD tier = 7+ sessions. → TASK-12

## Iteration hooks — "do until viral" loop

Queue is the board (`make board`); every hook is `make board-next`-able.
Suggested pull order for viral impact:

1. **TASK-13 Viral packaging (clone-and-run)** — the last mile: no-API-key demo path (stub agent / committed artifacts), one-command experience for a stranger. README hook + gifs already exist; this closes clone → wow in <60s.
2. **TASK-10 Retry-with-feedback** — pipe gate output into the retry agent's prompt. Attacks ceiling #1; directly raises matrix scores (haiku/sonnet died on gates that feedback would fix).
3. **TASK-2 HITL approvals default** — flips the documented design live; makes the "approval is a file" demo-able, which is the most tweetable primitive here.
4. TASK-15 planner JSON hardening (kills the observed 2-retry tax) → TASK-9 classifier tuning.
5. TASK-7 ffmpeg contact-sheet + diff-video — iteration-visible-as-media, feeds the viral loop's content engine.
6. TASK-6 CDP pool, TASK-8 TUI eval pack, TASK-12 cost accounting, TASK-4 evalgen — depth, pull as needed. (TASK-11 nested decomposition: Done.)

Loop protocol with user: pick hook → `make board-task TASK=…` (or hand-build) →
gates green → update this file's scores/ceilings → re-judge → repeat.
