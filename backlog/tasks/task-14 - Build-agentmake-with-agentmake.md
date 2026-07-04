---
id: TASK-14
title: Build agentmake with agentmake
status: Done
assignee:
  - '@pi-fixer'
created_date: '2026-07-03 18:20'
updated_date: '2026-07-04 01:21'
labels: []
dependencies: []
references:
  - STEERING.md
priority: high
ordinal: 0
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Self-host: build the agentmake engine, with the agentmake engine, in this run dir. Everything below is self-contained - no repo exploration needed, build exactly this:

1. engine core makefile: goal.md -> plan.json -> jq-generated components.mk (make re-include restart) -> one build step per component, dep-ordered, parallel-safe under make -j, .DELETE_ON_ERROR resume semantics
2. plan gate: jq schema check - components non-empty, kebab-case ids, deps may only reference listed ids
3. stub agent: deterministic bash script with the same CLI contract as a real agent adapter (plan <goal> emits a JSON plan; build <id> writes the component files), so the produced engine is testable offline with zero LLM calls
4. progress census target: filesystem census of expected artifacts, done/total count, non-zero exit only on census error
5. mermaid graph target: parse the rule files back into graph TD edges

Constraints: GNU make + bash + jq + coreutils only; no network; no LLM calls inside any check. Gate: an end-to-end check must run the produced engine on a trivial example goal using the stub agent - plan gate passes, components build in dependency order, census reports all done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 STEERING.md arc executed end to end
- [x] #2 docs/dogfood-autopsy.md captures the dogfood attempt mess
- [x] #3 engine/board.mk exists and makes backlog the default board (make board-next)
- [x] #4 engine decomposes this task and builds itself from the board
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Dogfood attempt on own repo (done: dogfood-board-next/, dogfood-progress-json/)
2. Capture mess -> docs/dogfood-autopsy.md (done)
3. engine/board.mk: backlog = default board, make board-next end-to-end (done)
4. Rewrite this description as the buildable self-host goal (board.mk contract: description = goal body)
5. make board-next -> engine pulls THIS task, decomposes it, builds itself; artifacts committed under board/TASK-14/
6. Check ACs via CLI as they become true; README dogfood-story section last
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Run 1+2 hit the plan gate: tool-less planner roleplayed fake tool calls exploring STEERING.md/docs refs in the description; jq gate rejected, .DELETE_ON_ERROR cleaned up. Fix: description made self-contained (this edit). Engine-side hardening split out to its own task.

board-next run: all gates passed; artifacts in board/TASK-14/

Self-host run 3 green end-to-end: make board-task TASK=TASK-14 -> 7 components (stub-agent, plan-gate, components-generator, engine-core-makefile, census-target, mermaid-target, e2e-check), dep-ordered -j2, every check.sh green, review VERDICT: PASS, census 10/10, wfcheck 32/32 (score 1). Artifacts committed under board/TASK-14/.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-07-04 01:21
---
Naming correction (2026-07-04): project renamed agentmake -> create-mvp (USER OVERRIDE, docs/naming.md; repo qwadratic/create-mvp, CLI bin/create-mvp ex bin/cook). Task title/body kept as recorded history — the self-host run happened under the old name.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
STEERING arc executed end to end. (1) Dogfood: two real self-development runs committed verbatim (dogfood-board-next/, dogfood-progress-json/) - gates green, zero integration. (2) Mess captured with verbatim tree snapshot in docs/dogfood-autopsy.md. (3) engine/board.mk makes backlog the default board: make board-next pulls top To Do task, materializes description as goal.md in board/<id>/, runs pipeline, marks Done via backlog CLI on gate pass; failed gates leave task In Progress and the run resumable. (4) Self-host: board-next pulled this task, engine decomposed it into 7 components and built a working engine copy, e2e-checked with a deterministic stub agent; review VERDICT: PASS, wfcheck 32/32 (score 1), artifacts in board/TASK-14/. README section 'Eating the dogfood' tells the mess->board story; roadmap contradiction removed. Follow-up: task-15 planner JSON hardening (runs 1-2 evidence).
<!-- SECTION:FINAL_SUMMARY:END -->
