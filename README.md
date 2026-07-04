# create-mvp

**Agents write the DAG. `make` runs the agents.**

You write a goal file. A planning agent decomposes it into components with
dependencies; `jq` turns that plan into makefile rules; GNU make schedules one
build agent per component — parallel with `-j`, resumable by default, and gated
at every step by mechanical checks. A component too big for one agent is marked
*composite* and becomes its own nested project — own goal, own plan, own swarm,
recursively, depth-bounded. There is no orchestrator daemon and no framework:
the entire engine is [~120 lines of Makefile](engine/build.mk).

![the engine, live](media/engine-run.gif)

*Real, unedited rebuild of `demos/game-of-life` — `make clean && make -j2`:
classify → plan → three build agents → review gate, then `make progress` and
`make graph`. Idle time capped at 2s (`asciinema rec -i 2`), so agent thinking
pauses are compressed; nothing else is. Cast file:
[`media/engine-run.cast`](media/engine-run.cast).*

## One command: `create-mvp`

One name everywhere: `create-mvp` is the repo you clone and the command you type — the `create-react-app` scaffolder lineage.

```sh
bin/create-mvp "an extension that makes all websites pink"
```

No Makefile authoring, no goal file editing — say the thing, get software.
`create-mvp` slugs your sentence into a project dir under cwd, writes `goal.md`
verbatim, drops the 3-line Makefile, and runs the full pipeline with a live
progress bar; it exits with the artifact paths and the run's
[wfcheck](evals/wfcheck) score. No API key? `bin/create-mvp --runtime mock "..."`
is the same one-shot on the deterministic mock agent.

```
 ✓ classify   tier=vague
 ✓ plan       3 components
 ✓ pink-css
 ✓ manifest
 · extension-app
 · review
[################--------] 4/6 (66%)
```

| | |
|---|---|
| `--dry` | classify + plan only — prints the component tree and the cost posture (2 agent calls, zero builds) |
| `--tier vague\|standard\|prd` | override the classifier — the budget dial, by hand |
| `--runtime cli\|sdk\|mock` | agent harness; `mock` runs the whole pipeline with zero LLM calls |
| `--board` | don't build now — file the goal as a Backlog.md task (`make board-task` later) |
| `--resume <dir>` | continue a stopped or failed run exactly where it left off (plain `make` resume) |
| `--dir`, `--jobs` | project dir override; `-j` fan-out (default 2) |
| `create-mvp progress <dir>`, `create-mvp graph <dir>` | census bar / mermaid DAG passthroughs |

The goal text is a trust boundary: it lands in `goal.md` verbatim and
nowhere else — the directory name is derived through a `[a-z0-9-]` charset
gate, and nothing from the sentence is ever interpolated into the Makefile
or a shell line. Self-checks (mock runtime, includes an injection attempt):
[`bin/selfcheck-create-mvp.sh`](bin/selfcheck-create-mvp.sh). `create-mvp` is orchestration
only — everything below it is the same engine you can drive by hand.

## 60-second quickstart

No API key, no LLM, no config — just `make` and `jq`:

```sh
git clone https://github.com/qwadratic/create-mvp && cd create-mvp
make demo-mock   # full pipeline on a deterministic mock agent, ~1s
ln -s "$PWD/bin/create-mvp" ~/.local/bin/create-mvp   # optional: the `create-mvp` binary on PATH
```

That runs the *entire real engine* — classify → plan → parallel builds →
review gate, including one composite component recursing into its own nested
subtree — with [a 60-line bash stub](engine/fixtures/mock-agent) standing in
for the LLM. It ends with the progress census, the mermaid dependency graph
(nested subgraph included), and a `wfcheck` grade of the finished run
(17/17). What you *don't* see is agents thinking; everything else — the DAG,
the gates, the resume semantics — is exactly what the real runs below use.

Got the `pi` (or `claude`) CLI on PATH with an API key? Same engine, real
agents:

```sh
make demo        # wipes + rebuilds demos/game-of-life from its 33-byte goal
```

Real agents, real gates, ends with the artifact census and the dependency
graph. Pick a bigger one with `make demo DEMO=twitter-x`. The gif above *is*
that run.

Your own project is a folder with two files — `create-mvp` writes both for you,
or by hand:

```sh
mkdir my-thing && cd my-thing
echo "a pomodoro timer, keyboard only" > goal.md
printf 'GOAL ?= goal.md\ninclude ../create-mvp/engine/build.mk\n' > Makefile
make -j4
```

## You get what you ask for

Phase 0 of every run classifies *your* effort. A one-liner gets a small, cheap
swarm and a smoke review; a full PRD gets a wide fan-out, a big model, and a
reviewer that checks every acceptance criterion. Same command either way —
the prompt is the budget dial. All six demos below were built by the engine
from the goal file shown, unedited:

| demo | the prompt | tier → plan | what came out | |
|---|---|---|---|---|
| [game-of-life](demos/game-of-life/) | ["game of life, make it look alive"](demos/game-of-life/goal.md) — 33 bytes | vague → 3 components, smoke review | canvas GoL with age-fade trails, seeded-PRNG eval page, SSIM golden gate. wfcheck 16/16 | <img src="media/game-of-life.gif" width="200"> |
| [desk-dashboard](demos/desk-dashboard/) | [94-byte one-liner](demos/desk-dashboard/goal.md) ("…make it pretty") | standard → 5 components | clock/weather/todo dashboard, live open-meteo fetch; first screenshot eval caught invisible-at-first-paint panels, fixed forward. wfcheck 24/24 | <img src="media/desk-dashboard.gif" width="200"> |
| [tui-habits](demos/tui-habits/) | [144-byte one-liner](demos/tui-habits/goal.md) | standard → 5 components | curses habit tracker, streak logic, `tmux capture-pane` text goldens. wfcheck 24/24 | <img src="media/tui-habits.gif" width="200"> |
| [twitter-x](demos/twitter-x/) | [5.4 KB PRD](demos/twitter-x/goal.md) | prd → 7 components, full review | X-clone timeline on 3 load-balanced backends (WAL sqlite), round-robin proxy, load stand proving a perfect 105/105/105 split, visual eval ssim 1.0. Built `-j2`. wfcheck 32/32 | <img src="media/twitter-x.gif" width="200"> |
| [forth-forth](demos/forth-forth/) | [5.8 KB PRD](demos/forth-forth/goal.md) | prd → 7 components, full review | Forth compiler written in Forth, staged bootstrap, byte-exact pinned goldens — and the stretch goal: [self-hosting fixed point](demos/forth-forth/README.md), gen1 == gen2. First run, zero retries. wfcheck 32/32 | <img src="demos/forth-forth/shots/selfhost.png" width="200"> |
| [site-forge](demos/site-forge/) | [6.2 KB PRD](demos/site-forge/goal.md) with a subsystem inside | prd → 6 components, **1 composite** | static site generator whose plugin subsystem became its own *nested project*: the planner marked it composite on the first call, the subtree self-planned 5 components (loader, hook API, 2 plugins, integration) and passed its own review. Two themes with SSIM-1.0 goldens; forge builds its own docs site. wfcheck parent 29/29, subtree 24/24 | <img src="demos/site-forge/shots/midnight.png" width="200"> |

33 bytes bought 3 agents and a smoke check. 5.8 KB of PRD bought 7 agents, a
full-rubric reviewer, and a compiler that compiles itself. Details:
[docs/effort-and-hitl.md](docs/effort-and-hitl.md).

![gallery](media/gallery.png)

## How it works

```
goal.md ──▶ classify ──▶ effort.json     (jq schema gate)
        ──▶ plan ──────▶ plan.json       (jq: components > 0)
                 jq -r ▶ components.mk   (make re-includes itself, DAG restart)
                         one build agent per component, dep-ordered, -j parallel
                         each gated by its own src/<id>/check.sh
        ──▶ review ────▶ report.md       (grep -q 'VERDICT: PASS')
```

The trick is make's `-include` restart: `components.mk` is *generated from the
agent's plan* by one `jq -r` line, then make restarts with a DAG shaped exactly
like the decomposition. `.DELETE_ON_ERROR` means a failed agent's artifact is
deleted, so a failed agent never counts as done — and rerunning `make` resumes
precisely where it stopped. Progress is a filesystem census (`make progress`),
and `make graph` parses the rule files back into mermaid. This is
`make -C demos/game-of-life graph`, verbatim except `$(COMPONENTS)` expanded to
its three members so it renders:

```mermaid
graph TD
  goal.md --> build/effort.json
  build/effort.json --> build/plan.json
  goal.md --> build/plan.json
  build/plan.json --> build/components.mk
  build/plan.json --> build/life-engine.done
  build/plan.json --> build/canvas-renderer.done
  build/life-engine.done --> build/canvas-renderer.done
  build/plan.json --> build/animation-app.done
  build/life-engine.done --> build/animation-app.done
  build/canvas-renderer.done --> build/animation-app.done
  build/components.mk --> build/report.md
  build/life-engine.done --> build/report.md
  build/canvas-renderer.done --> build/report.md
  build/animation-app.done --> build/report.md
  build/report.md --> all
```

**And it recurses.** A plan component may be `"kind": "composite"` with its own
`sub_goal`: the same `jq -r` line then emits a `+$(MAKE) -C src/<id>` recursion
instead of a build agent, and the subtree runs this same engine file — own
classify, own plan, own swarm, own review, whose verdict bubbles up as the
parent's `.done`. Planning stays lazy (a subtree is planned only when its turn
comes), and the bounds are deterministic jq/make, not prompt trust: a depth cap
(`AGENTMAKE_MAXDEPTH`, default 3) forces leaves at the cap, the subtree's
effort tier is clamped to its parent's (`MAXTIER`), and per-level fan-out is
gated at 8 (`MAXFANOUT`). `make progress` renders per-level bars and
`make graph` emits a mermaid subgraph per composite. Validated on a real PRD:
[demos/site-forge](demos/site-forge/). Design + hostile-case analysis:
[docs/rfc-nested.md](docs/rfc-nested.md).

Every make feature doing real work here — sentinel `.done` targets, order-only
prerequisites, the `$$` two-pass escape, `-j` as a free agent scheduler,
command-line variable origin beating a child's `?=` — is documented with
verbatim excerpts in [docs/engine-internals.md](docs/engine-internals.md).

## Evals: agents lie, files don't

Nothing counts as done until a mechanical check says so. Every eval's exit
code is its verdict, so any of them can sit on a recipe line as a gate:

| tool | checks |
|---|---|
| [`evals/snap`](evals/snap) | HTML → lowres PNG screenshot, ~0.2s/shot ([benchmarks](evals/docs/BENCH.md)) |
| [`evals/evalshot`](evals/evalshot) | screenshot vs. committed golden via ffmpeg SSIM (≥ 0.97); failure writes a `.diff.png` |
| [`evals/apieval`](evals/apieval) | live JSON API → `jq` reshape → [TOON](https://toonformat.dev) encode → diff vs. golden |
| TUI goldens ([recipe](evals/docs/TUI.md)) | `tmux capture-pane` 80×24 text grid vs. `.txt` golden — a terminal is already deterministic |
| [`evals/wfcheck`](evals/wfcheck) | grades a whole finished run: plan schema, DAG validity, check.sh re-runs, census, review verdict → `wfscore.json` |
| [`evals/matrix`](evals/matrix) | same goal through the engine per model; wfcheck score + wall + tokens + cost |

A TOON golden from the twitter-x demo — keys declared once, rows diff cleanly,
volatile fields already stripped by the `.jq` reshape
([`goldens/timeline.toon`](demos/twitter-x/goldens/timeline.toon), re-checked
live on every `run.sh --check` via `apieval`):

```
le_limit: true
newest_first: true
seed_tweets[8]{handle,id,likes,name,replies,retweets,text,ts}:
  elonrusk,1,88400,Elon Rusk,4821,9210,Shipping the new algorithm next week. It's going to be wild.,Jul 1
  sundarp,2,15300,Sundar P.,812,2100,"AI will change how we search, code, and create. Excited for what's next.",Jun 30
  gvanrossum,3,9800,Guido van Rossum,233,1400,"Reminder: readability counts. Your future self will thank you.",5h
  ...
```

And the multi-model matrix, same `wordfreq` goal, same gates
([full report](evals/matrix-results.md)):

| model | wfcheck | score | make | wall (s) | components | tokens | cost (USD) |
|---|---|---|---|---|---|---|---|
| anthropic/claude-haiku-4-5 | 19/20 | 0.95 | exit 2 | 265 | 4 | 547067 | 0.2676 |
| anthropic/claude-sonnet-4-6 | 28/32 | 0.88 | exit 2 | 127 | 7 | 211574 | 0.2785 |
| google/gemini-flash-latest | 28/28 | 1 | ok | 321 | 6 | 1247976 | 1.9685 |

`make` ≠ ok means a gate rejected honestly — `.DELETE_ON_ERROR` threw the
artifact away rather than shipping it. Golden update protocol (an agent is
never allowed to retire its own golden) and the full toolbox:
[docs/evals.md](docs/evals.md).

## The HITL switch

Approval is a file. `build/approvals/<step>.ok` depends on
`build/<step>.done`; downstream targets consume the `.ok`. Rebuild a step and
its approval is stale by timestamp — the gate re-opens itself. No daemon, no
state, survives restarts:

```sh
# design — pattern rules live in docs/effort-and-hitl.md, not yet wired into engine/build.mk
make AUTOPILOT=1                # approver agent gates every step (must print APPROVE)
make -k                         # default: human gates; -k lets siblings keep building
make pending                    # list open gates
make approve-http-api           # records who/when/sha256 of what was approved
make HUMAN_STEPS="db auth"      # force human on these even under AUTOPILOT=1
```

Full design (and the alternatives it beat):
[docs/effort-and-hitl.md](docs/effort-and-hitl.md).

## Runtime

The agent adapter ([`engine/agent`](engine/agent)) is ~150 lines of bash; the
harness is pluggable:

```sh
make                           # RUNTIME=cli, ENGINE_CLI=pi (default)
make ENGINE_CLI=claude         # claude CLI; thinking levels map to --effort
make RUNTIME=sdk               # in-process pi SDK (engine/runtime-sdk.mjs)
ENGINE_CLI_FLAGS="--model x" make    # passthrough flags
MODEL_SMALL=... MODEL_LARGE=... make # what the classifier's model hints resolve to
```

Per-unit overrides (route one hard component to a big model without upgrading
the whole run) go in `build/effort.json` — see the header of `engine/agent`.

## Eating the dogfood: why the board is the default

We pointed the engine at its own repo — one ad-hoc `goal.md` per engine
improvement, the tool's own documented workflow. Both runs came back green:
every `check.sh` passed, both reviews said `VERDICT: PASS`. And both were
failures. Asked to integrate with "our backlog board", the agents never found
the real board sitting two directories up — they invented their own board
format and built a gate-passing pipeline against their own fixtures. The
other run left a stray `report.md` at the wrong level and reached outside its
run dir. Root of the repo: two clutter directories, two orphan
`effort.json`, zero improvements landed. The full mess is committed verbatim
(`dogfood-board-next/`, `dogfood-progress-json/`) and dissected in
[docs/dogfood-autopsy.md](docs/dogfood-autopsy.md).

The lesson: gates measure internal consistency, not integration — and ad-hoc
goal files carry no queue semantics. No discovery, no lifecycle, no ordering,
one clutter dir per idea. Every one of those is a work-queue problem, and the
repo already had a work queue: the [Backlog.md board](backlog/tasks/). So the
board is now the engine's default goal source
([`engine/board.mk`](engine/board.mk)):

```sh
make board                     # the queue, straight from the backlog CLI
make board-next                # top To Do task -> board/<id>/goal.md -> pipeline
                               #   -> gates pass -> task marked Done via the CLI
make board-task TASK=TASK-7    # explicit pick; also the resume path — a failed
                               #   gate leaves the task In Progress, rerun continues
```

Task = goal unit. The task *description* is the goal body; acceptance
criteria stay on the board and get checked via the CLI as gates pass. Backlog
CLI only — nothing edits `backlog/**/*.md` by hand.

Proof it closes the loop: the board's task-14 — *“Build agentmake with
agentmake”* — was pulled by `make board-next`, decomposed by the engine into
7 components (stub agent, plan gate, components generator, engine core
makefile, census, mermaid graph, e2e check), built dep-ordered under `-j2`,
and passed full review — the produced engine runs a goal end-to-end with a
deterministic stub agent, no LLM in the checks.
[wfcheck](evals/wfcheck): 32/32, score 1.0. Run artifacts:
[`board/TASK-14/`](board/TASK-14/). It took three runs — the first two died
at the plan gate when the planner hallucinated tool calls instead of JSON
(`.DELETE_ON_ERROR` cleaned up, the task stayed In Progress, rerun resumed);
the fix and the follow-up hardening task are on the board.

## pi extension: demo mode

```sh
pi -e extension/index.ts                                  # try it once
ln -s "$PWD/extension" ~/.pi/agent/extensions/create-mvp   # install
```

Locks the session to a single `create_mvp_demo` tool (built-ins disabled),
streams `make` progress live, adds a `/demo <dir>` command, and bundles the
[`agentic-makefile` skill](extension/skills/agentic-makefile/SKILL.md) so plain
pi sessions know how to scaffold and drive the pipeline.

## Roadmap

Lives on the [Backlog.md board](backlog/tasks/) (`backlog board` to view) —
which is also the engine's work queue, so any item below is one
`make board-next` away from being attempted: retry-with-feedback loops,
planner JSON output hardening, per-artifact token accounting, persistent CDP
screenshot pool, and more. (Nested decomposition graduated off this list —
see [demos/site-forge](demos/site-forge/).)

## Honest limitations

- **No feedback on retry.** A failed gate deletes the artifact; rerunning
  `make` fires a *fresh* agent with no memory of why the last one failed.
  (Agents do iterate against their own `check.sh` within a session — the
  desk-dashboard fix-forward loops — but the engine doesn't pipe gate output
  back yet.)
- **HITL approvals are designed, not default.** `engine/build.mk` ships with
  `.done → .done` edges; wiring the `.ok` layer is a one-line jq change plus
  the documented pattern rules.
- **Sibling integration is copy-based.** Nested decomposition landed (composite
  components recurse, depth ≤ 3, fan-out ≤ 8 per level), but siblings integrate
  by copying each other's files per the plan's description contract — no shared
  artifact store, so a subtree can drift from the sibling it copied. And the
  composite-marking decision has exactly one real-PRD validation datapoint
  (site-forge) so far.
- **Tool-less planners can roleplay.** Deny tools to a planning agent and
  hand it a goal that references files, and it may hallucinate an entire
  tool-call transcript before the JSON (observed on the self-host run — the
  jq gate rejected it twice; retries are paid). Hardening is task-15 on the
  board.
- **Plans are nondeterministic.** Same goal, different runs, different
  component splits. The gates hold either way, but `build/` is not
  bit-reproducible; matrix wall/cost numbers are single-run trends.
- **It spends real money.** The matrix goal — a small CLI — cost $0.27–$1.97
  per run depending on model. A PRD-tier build fans out to 7+ agent sessions.
- **`snap` boots a browser per shot** (~190 ms). Fine at ≤5 shots per check;
  the persistent-CDP-pool upgrade is measured and specced in
  [BENCH.md](evals/docs/BENCH.md) but not built.
- **`make graph` is an awk parser**, not a make introspector: `$(COMPONENTS)`
  prints unexpanded and exotic prerequisite syntax would be missed.
- **First-run goldens are self-seeded.** `evalshot`/`apieval` bootstrap their
  golden from current output with a loud NOTE — a human must eyeball it before
  committing, or the gate gates nothing.

## Docs

- [Engine internals](docs/engine-internals.md) — the make features doing the work, with verbatim excerpts
- [Evals](docs/evals.md) — the toolbox, when each fires, golden update protocol
- [Effort & HITL](docs/effort-and-hitl.md) — effort tiers, knob plumbing, the approval-file design
- [Dogfood autopsy](docs/dogfood-autopsy.md) — the mess that made the board the default, tree snapshot verbatim
