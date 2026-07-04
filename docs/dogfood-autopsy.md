# Dogfood autopsy — why the board is the default now

STEERING arc step 2: develop agentmake *with* agentmake — one ad-hoc
`goal.md` per engine improvement, engine pipeline pointed at its own repo.
This is the unedited evidence. Nothing was cleaned up before the snapshot;
the directories are committed as they landed.

## What was attempted

Two real engine improvements off the roadmap, each run as the engine's own
documented workflow — a folder with two files:

```sh
mkdir dogfood-board-next
echo "make target that pulls the next todo task from our backlog board and turns it into a goal.md the engine can build" > dogfood-board-next/goal.md
printf 'GOAL ?= goal.md\ninclude ../engine/build.mk\n' > dogfood-board-next/Makefile
cd dogfood-board-next && make -j2 all      # same for dogfood-progress-json
```

Both runs *succeeded* by the engine's own gates: every `check.sh` green,
both reviews end `VERDICT: PASS`. That is the problem.

## The mess (tree snapshot, verbatim)

`find dogfood-board-next dogfood-progress-json -type f | sort`, taken before
anything was moved:

```
dogfood-board-next/Makefile
dogfood-board-next/build/board-reader.done
dogfood-board-next/build/components.mk
dogfood-board-next/build/effort.json
dogfood-board-next/build/goal-md-generator.done
dogfood-board-next/build/make-target.done
dogfood-board-next/build/next-task-selector.done
dogfood-board-next/build/plan.json
dogfood-board-next/build/report.md
dogfood-board-next/goal.md
dogfood-board-next/src/board-reader/board-reader.js
dogfood-board-next/src/board-reader/check.sh
dogfood-board-next/src/board-reader/fixtures/board.md
dogfood-board-next/src/goal-md-generator/check.sh
dogfood-board-next/src/goal-md-generator/fixtures/task.json
dogfood-board-next/src/goal-md-generator/goal-md-generator.js
dogfood-board-next/src/make-target/Makefile
dogfood-board-next/src/make-target/check.sh
dogfood-board-next/src/next-task-selector/check.sh
dogfood-board-next/src/next-task-selector/fixtures/three-tasks.jsonl
dogfood-board-next/src/next-task-selector/next-task-selector.js
dogfood-progress-json/Makefile
dogfood-progress-json/build/components.mk
dogfood-progress-json/build/effort.json
dogfood-progress-json/build/json-emitter.done
dogfood-progress-json/build/json-schema-def.done
dogfood-progress-json/build/make-progress-json-target.done
dogfood-progress-json/build/parity-check.done
dogfood-progress-json/build/plan.json
dogfood-progress-json/build/progress-data-collector.done
dogfood-progress-json/build/report.md
dogfood-progress-json/goal.md
dogfood-progress-json/report.md
dogfood-progress-json/src/json-emitter/check.sh
dogfood-progress-json/src/json-emitter/emit.py
dogfood-progress-json/src/json-schema-def/README.md
dogfood-progress-json/src/json-schema-def/check.sh
dogfood-progress-json/src/json-schema-def/example.json
dogfood-progress-json/src/json-schema-def/progress.schema.json
dogfood-progress-json/src/json-schema-def/validate.py
dogfood-progress-json/src/make-progress-json-target/Makefile
dogfood-progress-json/src/make-progress-json-target/check.sh
dogfood-progress-json/src/parity-check/check.sh
dogfood-progress-json/src/parity-check/parity.py
dogfood-progress-json/src/progress-data-collector/__pycache__/collect.cpython-314.pyc
dogfood-progress-json/src/progress-data-collector/check.sh
dogfood-progress-json/src/progress-data-collector/collect.py
```

Two improvements → two root-level clutter dirs, two scattered `build/` trees,
two orphan `effort.json`, a stray `report.md` at the wrong level, a
`__pycache__` turd. Linear growth: improvement N means clutter dir N.

## What went wrong, specifically

1. **The engine invented a parallel universe instead of using the repo's.**
   The goal said "our backlog board". This repo *has* a board —
   `backlog/tasks/` with a CLI. The build agents never found it: they
   invented their own markdown board format
   (`src/board-reader/fixtures/board.md`, `# Backlog Board / ## todo`), a
   position-based task ID scheme, an `Acceptance:` marker convention. Four
   components, all gates green, review PASS — for a board that exists
   nowhere but its own fixtures. The review itself flagged it and passed
   anyway: *"board task IDs are position-based (unstable across edits)"*.

2. **Green gates ≠ integrated.** Every `check.sh` passes; nothing landed in
   `engine/`. Both deliverables sit siloed under `dogfood-*/src/` where no
   `include` reaches them. The gates measure internal consistency of the run
   dir — not "did this improve the tool"; an ad-hoc goal file carries no link
   back to the tool's actual state or work queue.

3. **Artifacts leak and duplicate.** The progress-json reviewer wrote its
   report twice — `build/report.md` (the gated one) and a stray
   `./report.md`. The parity-check component reached *outside its own run
   dir* and ran `make progress` against whatever it found. Ad-hoc dirs inside
   the tool's own repo have no boundary contract.

4. **No queue semantics.** Which improvement is next? What's in flight? Done?
   The answer lived in two places that don't talk: the real board in
   `backlog/` (untouched by all of this) and a pile of directories whose only
   status signal is `ls */build/*.done`. Priority, ordering, done-tracking —
   all solved by the board the dogfood runs ignored.

## Why a board

The failure mode is not the engine — both runs built working, gated code.
The failure mode is **goal files as a work queue**: no discovery (agents
can't find the real board from a prose one-liner), no integration pressure
(nothing routes output back), no lifecycle (todo/doing/done lives nowhere),
no scaling (root dir grows one clutter folder per idea).

All four are queue problems, and the repo already ships a queue:
Backlog.md + CLI. Hence STEERING step 3 — `engine/board.mk` makes the board
the engine's default goal source: `make board-next` pulls the top To Do task
via the backlog CLI, materializes it as `goal.md` in a *managed* run dir
(`board/<TASK-ID>/`), runs the pipeline, marks the task Done via the CLI when
the gates pass. Task = goal unit; status lives on the board; run artifacts
land in one predictable place.

The dogfood dirs stay committed as-is. The mess is the argument.
