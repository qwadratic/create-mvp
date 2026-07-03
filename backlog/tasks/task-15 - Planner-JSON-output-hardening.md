---
id: TASK-15
title: Planner JSON output hardening
status: To Do
assignee: []
created_date: '2026-07-03 19:55'
labels: []
dependencies: []
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tool-less plan/classify agents can emit prose (observed: hallucinated tool-call transcripts when the goal references repo files) before the JSON. jq gate catches it, but every retry is a fresh paid session. Harden engine/agent: extract trailing JSON object from plan/classify output (e.g. from last line starting with {), and/or retry-once-with-feedback. Evidence: board/TASK-14 self-host run 1-2, task-14 notes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 plan/classify JSON extracted from noisy output, jq gates still the arbiter
- [ ] #2 covered by a stub-runtime test, no paid calls
<!-- AC:END -->
