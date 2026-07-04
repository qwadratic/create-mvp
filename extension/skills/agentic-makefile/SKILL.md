---
name: agentic-makefile
description: Turn a buildable software goal into a running create-mvp pipeline. Use when the user states a goal that decomposes into components ("build me a twitter clone", "make a todo API + web UI"). Scaffold goal.md plus a 3-line Makefile that includes engine/build.mk, then run make to plan, build, and review with dep-ordered parallel agents.
---

# agentic-makefile

Engine: `../../../engine/build.mk` relative to this skill dir (canonical layout: `<repo>/engine/`).

Pipeline: `goal.md` → plan agent → `plan.json` → jq-generated `components.mk` DAG →
one build agent per component (dep-ordered, parallel with `-j`, gated by per-component
`check.sh`) → reviewer agent gate (`VERDICT: PASS` in `build/report.md`).
`.DELETE_ON_ERROR` means a failed agent never counts as done — rerunning `make` resumes
exactly where it stopped.

## Workflow

1. **Classify effort** (table below). Trivial → skip the engine, just do it.
2. **Scaffold** a project dir:
   - `goal.md` — plain prose, one paragraph. Concrete deliverables + constraints.
   - `Makefile`:
     ```make
     GOAL ?= goal.md
     include ../../engine/build.mk
     ```
     That include path assumes the dir lives at `demos/<name>/` inside the create-mvp
     repo. Outside the repo: copy or symlink `engine/` next to the project and use
     `include engine/build.mk`.
     Shortcut: `bin/create-mvp "goal text"` (the repo's one-shot CLI) does steps 2–3 —
     scaffolds goal.md + Makefile, runs the pipeline.
3. **Run**: `make -C <dir> -j4 all`.
   In demo mode (the create-mvp pi extension) built-in tools are disabled — use the
   `create_mvp_demo` tool instead; demos there are pre-scaffolded.
4. **Monitor**: `make -C <dir> progress` (artifact census with bar),
   `make -C <dir> graph` (mermaid dependency graph).
5. **Verify**: gates already enforce plan validity (`jq -e` on `plan.json`),
   per-component `check.sh`, and reviewer `VERDICT: PASS`. Report that verdict —
   do not re-review by hand.
6. **On failure**: rerun `make` first (it resumes). Persistent failure → inspect
   `build/` artifacts, sharpen `goal.md`, rerun. Last resort: `make clean`
   (wipes `build/` and `src/`).

## Effort classifier

| class | signal | route |
|-------|--------|-------|
| trivial | one file, one command, or a pure answer | no engine — do it directly |
| standard | 2–8 separable components, stdlib-buildable | engine pipeline, autopilot |
| high-stakes | destructive ops, security-sensitive, user asks for review, >8 components | engine + HITL gates |

## HITL switch

Gate design (makefile-lab `evals/DRIFT-DESIGN.md` §2.3): approval = file.
`build/approvals/<step>.ok` depends on `build/<step>.done`; downstream deps consume
the `.ok`, so a rebuild (`.done` newer than `.ok`) automatically re-opens the gate.

Knobs — all at invocation time, no Makefile edits:

- `make AUTOPILOT=1` — a reviewer agent auto-approves every gate
- default (`AUTOPILOT=0`) — human approves: `make approve-<step>`;
  list open gates with `make pending`; revoke with `make unapprove-<step>`
- per-step override: `HUMAN_STEPS="db auth"` forces human, `AUTO_STEPS="ui"` forces auto

Status: the current `engine/build.mk` ships WITHOUT the approvals block — dep edges go
straight `.done → .done`. When the user requests HITL, wire the gate per
DRIFT-DESIGN §2.3: add the `$(APPROVALS)/%.ok` pattern rule + `approve-%`/`pending`
helpers, and point the jq `components.mk` generator's dep edges at
`$(B)/approvals/<dep>.ok` instead of `$(B)/<dep>.done`.
