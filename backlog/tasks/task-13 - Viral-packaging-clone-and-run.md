---
id: TASK-13
title: Viral packaging (clone-and-run)
status: Done
assignee: []
created_date: '2026-07-03 18:11'
updated_date: '2026-07-04 00:48'
labels:
  - idea
dependencies: []
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Polish repo for clone-and-run: README quickstart, demo table, media (gifs), zero-config first run.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Readiness sweep landed the packaging set: (1) LICENSE MIT (c) 2026 qwadratic (c7f8170). (2) make demo-mock — zero-key front door: full engine pipeline (classify→plan→-j2 builds→nested subtree→review) on engine/fixtures/mock-agent, ends with progress + graph + wfcheck 17/17, measured ~1s wall (ad39145). (3) README quickstart reordered: no-key demo-mock path FIRST, real-agent make demo second; truthful for a stranger with zero keys. Media/gifs + demo table already in README from earlier work. Security sweep clean this session (gitleaks full history 0 leaks). gh description+topics drafted in workflow output pending repo publish.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Clone-and-run packaging complete: MIT LICENSE, zero-config no-key first run (make demo-mock, ~1s, wfcheck 17/17), README quickstart leads with it, demo table + gifs already present. Verified by running make demo-mock end-to-end.
<!-- SECTION:FINAL_SUMMARY:END -->
