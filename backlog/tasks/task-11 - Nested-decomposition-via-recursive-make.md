---
id: TASK-11
title: Nested decomposition via recursive make
status: Done
assignee: []
created_date: '2026-07-03 18:11'
updated_date: '2026-07-03 21:52'
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
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Recursive decomposition per docs/rfc-nested.md: plan components may be kind=composite with sub_goal; jq template forks — leaf gets a build agent, composite gets engine/subtree scaffold + recursive $(MAKE) -C src/<id>. Bounds deterministic (AGENTMAKE_MAXDEPTH=3, MAXTIER tier clamp, MAXFANOUT=8) in jq/make, not prompt trust. progress/graph/wfcheck recurse; flat runs byte-identical. Verified mock-first (zero-LLM e2e fixture) then live on demos/site-forge real PRD (parent wfcheck 29/29, subtree 24/24).
<!-- SECTION:FINAL_SUMMARY:END -->
