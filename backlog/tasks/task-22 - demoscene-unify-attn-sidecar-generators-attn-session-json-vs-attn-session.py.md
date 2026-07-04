---
id: TASK-22
title: >-
  demoscene: unify attn sidecar generators (attn session --json vs
  attn-session.py)
status: To Do
assignee: []
created_date: '2026-07-04 00:32'
labels:
  - demoscene
  - follow-up
dependencies: []
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Judge round-2 completeness pass surfaced: two independent weight/tokenizer implementations emit out/session.attn.json. 'attn session --json' emits the ATTN-SPEC §5 shape; attn-session.py emits an extended superset (per-frame dominant_cat, cat_weights, decision_junctions, attn_label) that mk-timeline.py hard-requires. Committed sidecar was the wrong shape until 7608409 (fresh clone -> KeyError in mk-timeline). Drift hazard remains: formula changes must land in attn, attn-session.py, AND attn-proxy-check.py. Also SPEED=2.3 in mk-timeline.py must manually match 'agg --speed 2.3' (demoscene/README.md regen pipeline).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 attn session --json emits the extended frame fields (superset of spec §5); ATTN-SPEC §5 documents them
- [ ] #2 attn-session.py deleted or reduced to a thin wrapper over attn internals (single weight implementation)
- [ ] #3 mk-timeline.py consumes the unified sidecar; attn-selfcheck.py + attn-proxy-check.py still pass
- [ ] #4 SPEED/agg coupling either derived from one constant or asserted (timeline video_len vs raw.mp4 duration)
<!-- AC:END -->
