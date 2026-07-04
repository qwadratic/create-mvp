---
id: TASK-11
title: Nested decomposition via recursive make
status: Done
assignee: []
created_date: '2026-07-03 18:11'
updated_date: '2026-07-04 01:21'
labels:
  - idea
dependencies: []
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Components can decompose further: recursive $(MAKE) per subtree. Ceiling noted in engine/build.mk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Composite components recurse: subtree gets own goal + plan + components via recursive $(MAKE)
- [x] #2 Deterministic bounds (depth, tier, fanout) enforced by jq/make, not prompt trust
- [x] #3 Tooling recurses: progress, graph, wfcheck handle nested runs; flat behavior byte-identical
- [x] #4 Validated end-to-end on a real goal
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped across 3 commits: 641c274 (engine: composite kind + sub_goal, engine/subtree scaffold, +$(MAKE) -C recursion, AGENTMAKE_MAXDEPTH=3 / MAXTIER clamp / MAXFANOUT=8 as jq/make gates, mock-agent e2e with zero LLM calls), 258211c (progress per-level bars, graph mermaid subgraphs, wfcheck subtree recursion without score dilution, selftest nested fixtures, engine-internals doc), 1fefb74 (demos/site-forge: real 6.2KB PRD — planner marked plugin-subsystem composite on first call, subtree self-planned 5 components, wfcheck parent 29/29 + subtree 24/24, zero gate failures). Design doc: docs/rfc-nested.md. README front door updated in 8e949f5.

Validation rerun at finalization: nested-selftest PASS (tree build, order, idempotence, deep resume, bubble+resume, depth cap, fanout gate, tier clamp, wfcheck/progress/graph recursion); wfcheck-selftest 28/28 incl. nested-subtree break detection; apieval-selftest PASS; selfcheck-classify PASS; flat regression wfcheck demos/game-of-life 16/16; nested wfcheck demos/site-forge 29/29 (subtree 24/24 via drill-down).

Judge round (3 judges: make-correctness, trajectory-fitness, docs+hygiene): 2 rounds each. Round-1 criticals fixed in d9e190e (id charset allowlist ^[a-z0-9][a-z0-9-]{0,63}$ at plan gate + engine/subtree — plan ids splice into make+shell, trust boundary, not style) and 5e5c07e (spec/impl code-block sync + line-count staleness). Re-judge: make-correctness PASS on judge-built fixtures (jobserver -j4 real cross-subtree interleave, resume-at-depth exactly-1-rebuild, MAXDEPTH cap enforced in generated makefile text); trajectory-fitness PASS (composite boundary sensible, lazy sub-planning verified in buildlog order); docs+hygiene 10/10. Follow-ups filed: TASK-17 (mid-flight re-planning), TASK-18 (whole-tree census), TASK-19 (cross-subtree deps + artifact store).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-07-04 01:21
---
Naming correction (2026-07-04): project renamed agentmake -> create-mvp (USER OVERRIDE, docs/naming.md). Body references to agentmake kept as recorded history.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Recursive decomposition per docs/rfc-nested.md: plan components may be kind=composite with sub_goal; jq template forks — leaf gets a build agent, composite gets engine/subtree scaffold + recursive $(MAKE) -C src/<id>. Bounds deterministic (AGENTMAKE_MAXDEPTH=3, MAXTIER tier clamp, MAXFANOUT=8) in jq/make, not prompt trust. progress/graph/wfcheck recurse; flat runs byte-identical. Verified mock-first (zero-LLM e2e fixture) then live on demos/site-forge real PRD (parent wfcheck 29/29, subtree 24/24).
<!-- SECTION:FINAL_SUMMARY:END -->
