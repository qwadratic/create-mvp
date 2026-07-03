All 7 checks pass individually and simultaneously in parallel (stronger than `make -j2`). Golden screenshot verified visually: faithful X dark layout.

# Review Report: twitter-x

## Per-component verdicts

### db-seed — PASS
`seed.py`: fixed-id `INSERT OR IGNORE` → idempotent (verified: re-seed keeps count at 8). 8 tweets / 4 users, distinct avatar colors, fixed ts strings, non-zero engagement. `connect()` sets WAL + `busy_timeout=2000`. check.sh verifies all of F4.

### backend-server — PASS
ThreadingHTTPServer, port via argv/env, shared DB via seed.connect (WAL). All F1 endpoints present. check.sh covers: health JSON with port, timeline schema + newest-first + limit 50, POST→201 with created tweet, new tweet on top, 400 for missing/empty/281-char text, `GET /` serves HTML. Binds port 0 in check → parallel safe.

### reverse-proxy — PASS
Strict round-robin with lock, per-port counters. check.sh proves: X-Backend header, no repeat in first 3 requests, all 3 backends hit, method/path/query/body forwarded verbatim (stub echo), `/lb-stats` answered locally with exact counts 2/1/1 total 4, dead backend → 502 JSON with counter frozen. All of F2.

### ui-page — PASS
Single self-contained HTML, zero external URLs, all mandated colors (#000/#2f3336/#e7e9ea/#71767b/#1d9bf0), system-ui stack, nav rail with 5 inline-SVG items + X logo + Home active/bold, 600px bordered column, sticky Home header, compose with disabled-until-input Post button, tweet cards with avatar/name/handle·ts/action-row SVGs, right column search pill + trends. Fixed ts strings rendered as-is, no animations/autofocus. F3 satisfied.

### load-stand — PASS
Defaults `--requests 300 --concurrency 10`, 20% POST mix (i%5), prints per-backend counts, req/s, p50/p95. Exit-0 iff all counters within 10% of mean. check.sh proves both directions: balanced → exit 0, killed backend (skew) → nonzero. F5 satisfied.

### run-harness — PASS
`run.sh` seeds, boots 3 backends + proxy, 5s health deadline, trap cleanup, prints URLs. `--check` verifies A1 (3 distinct ports), A2 (schema + newest-first), A3 (POST via one backend, read via different backend — WAL proven), A4 (lb-stats delta exactly 9, then 300-req load stand → 0.0% deviation), A5 (no external URLs + layout markers). check.sh allocates 4 fresh ports. All checks passed live.

### visual-eval — PASS
`eval.sh` boots stack on free ports, `snap` at 1280×800, structural pixel asserts (dark bg mean lum, nav-rail bright+blue pixels, compose blue button, ≥4 avatar blobs → found 8), then `evalshot` vs golden: **ssim=1.000000 ≥ 0.97**. Golden inspected manually — genuine X dark layout with nav rail, compose box, 6+ visible tweet cards, right column. A6 satisfied.

## Integration verdict — PASS
- Full stack run (`run.sh --check`): A1–A5 all OK; load stand 315 total, perfect 105/105/105 split.
- Visual eval (A6): checkpixels PASS + evalshot ssim 1.0.
- Hard constraints: stdlib+sqlite only (verified imports), no CDN/external assets, all check.sh use port-0 allocation + traps, non-interactive, each <60s.
- Parallel-safety: all 7 checks run concurrently, all exit 0 — safe under `make -j2`.
- A7: every component ships executable check.sh.

No gaps found against goal.md acceptance criteria or edge cases.

VERDICT: PASS
