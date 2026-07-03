---
id: TASK-5
title: Multi-model eval matrix
status: Done
assignee:
  - '@agent4'
created_date: '2026-07-03 18:11'
updated_date: '2026-07-03 18:36'
labels:
  - idea
dependencies: []
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Run same goal across multiple models/harnesses, compare pass rates + cost.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. evals/apieval: curl->jq->toon->diff golden, bootstrap-on-first-run, self-check vs stdlib http fixture. 2. evals/wfcheck: plan schema+DAG, src+check.sh presence, check.sh reruns, census, review verdict -> build/wfscore.json. Self-check pass on twitter + fail on broken copy. 3. evals/matrix: pick 2-3 models from pi --list-models, run word-freq goal through engine per model, collect wfcheck score + wall time -> evals/matrix-results.md. Commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shipped evals suite: (1) evals/apieval — curl->jq -S -f->toon->diff golden, seed-on-first-run w/ loud NOTE; selftest spins stdlib http server, covers seed/pass/fail-on-drift/toon round-trip. (2) evals/wfcheck <dir> — plan schema, DAG (unknown ids + cycles via py toposort), per-component src/checksh/run/done checks, review verdict; emits build/wfscore.json {checks,passed,total,score}; selftest: twitter copy passes 28/28, broken copies (census/dag/gates) each blamed on right check. (3) evals/matrix — probes models from pi --list-models, runs fixed wordfreq goal per model in parallel, pins model via ENGINE_CLI_FLAGS, tokens/cost summed from pi session jsonl via new PI_SESSION_DIR passthrough in engine/agent; --report-only regenerates table. Ran live: haiku 0.95 (review verdict FAIL), sonnet-4-6 0.88 (build agent misplaced check.sh, gate 127), gemini-flash 1.0 but 5.9x haiku tokens. Gates rejected honestly — that IS the eval. Raw .sessions/ gitignored, usage.json committed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Multi-model eval matrix live: evals/matrix runs same wordfreq goal through engine per model (haiku/sonnet/gemini-flash), scores via new evals/wfcheck (plan/DAG/gates/census/verdict -> wfscore.json), tokens+cost from pi session files. Results in evals/matrix-results.md. Plus evals/apieval (jq+TOON API goldens) with stdlib-http selftest. engine/agent gained PI_SESSION_DIR session passthrough. Verified: both selftests pass, matrix executed live with honest gate failures.
<!-- SECTION:FINAL_SUMMARY:END -->
