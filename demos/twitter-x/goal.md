# PRD: "twitter-x" — X (Twitter) clone with load balancing

## Summary
Pixel-faithful-ish clone of the X.com home timeline (dark theme), served by
N=3 load-balanced backend instances behind a round-robin reverse proxy, plus
a load stand that PROVES even request distribution across instances.
Everything runs locally.

## Hard constraints
- python3 stdlib + sqlite3 only. No docker, no pip, no network installs,
  no CDN assets — all CSS/SVG inline in the served HTML.
- Default ports: backends 9101/9102/9103, proxy 8080.
- check.sh scripts will run under `make -j2`: each check MUST allocate its own
  free ports at runtime (bind-port-0 trick or per-component unique range),
  never assume default ports are free, and always kill its own processes on
  exit (trap). Non-interactive, finishes < 60s.

## Functional requirements

### F1. Backend server (run as 3 instances)
- python3 `http.server` ThreadingHTTPServer; one process per instance,
  instance port via argv/env.
- All instances share ONE sqlite DB file: `journal_mode=WAL`,
  `busy_timeout >= 2000` ms — a write through any instance is immediately
  readable through the others.
- Endpoints:
  - `GET /api/health` → `{"ok": true, "port": <instance port>}`
  - `GET /api/timeline` → `{"tweets":[{"id","handle","name","avatar_color",
    "text","ts","replies","retweets","likes"}]}` newest-first, limit 50
  - `POST /api/tweets` body `{"text":"..."}` → 201 + created tweet JSON;
    400 on missing/empty/oversize (>280 chars) text
  - `GET /` → the UI page (single self-contained HTML, F3)

### F2. Reverse proxy + /lb-stats
- stdlib-only reverse proxy on one port, strict round-robin over the 3
  backends.
- Forwards method, path, query, headers, body; returns backend response
  verbatim plus header `X-Backend: <backend port>`.
- Thread-safe per-instance request counters. `GET /lb-stats` is answered by
  the proxy itself (never forwarded):
  `{"backends":[{"port":9101,"requests":N},{"port":9102,"requests":N},
  {"port":9103,"requests":N}],"total":N}`
- Backend connection failure → 502 JSON error, counter NOT incremented.

### F3. UI — visually faithful to X dark theme
Served at `GET /`. This must LOOK like X, not "a demo page":
- Colors: background #000, borders #2f3336, primary text #e7e9ea,
  secondary text #71767b, accent blue #1d9bf0. Font: system-ui stack.
- Layout: left nav rail (X logo, then Home/Explore/Notifications/Messages/
  Profile with inline-SVG icons, Home active/bold, rounded blue Post button);
  center timeline column ~600px wide, 1px #2f3336 side borders, sticky
  "Home" header; optional right column (round "Search" pill, "What's
  happening" card).
- Compose box at top of timeline: round avatar circle, "What's happening?"
  placeholder, rounded blue Post button (disabled until text entered).
- Tweet cards: round avatar (colored circle with user initial), bold display
  name, gray `@handle · <ts>` line, tweet text, gray action row with
  inline-SVG reply/retweet/like/views icons + counts.
- Posting works end-to-end: compose → `fetch POST /api/tweets` via proxy →
  timeline re-render shows new tweet on top.
- Deterministic render for screenshot evals: timestamps rendered as the fixed
  strings stored in seed data (never relative to wall clock), no animations,
  no autofocus/blinking caret.

### F4. Seed data
- Deterministic + idempotent (re-seed → no duplicates): ≥8 tweets from
  ≥4 users with realistic handles/display names, distinct avatar colors,
  fixed `ts` strings (e.g. "2h", "Jul 1"), non-zero engagement counts.

### F5. Load stand
- python3 stdlib script: `--requests` (default 300), `--concurrency`
  (default 10), `--url` (proxy base).
- Mix ≈80% `GET /api/timeline` / 20% `POST /api/tweets`, all through proxy.
- Afterwards fetches `/lb-stats`; prints per-backend counts, req/s, latency
  p50/p95.
- Exit 0 iff EVERY backend counter is within 10% of the mean
  (|count − mean| / mean ≤ 0.10); nonzero exit otherwise.

### F6. Run harness
- `run.sh`: seeds DB, boots 3 backends + proxy, waits for all 4 healthy
  within 5s, prints URLs, cleans up children on exit (trap).
- `run.sh --check`: boots, verifies A1–A5 below, shuts down, exits by result.

## Acceptance criteria
- A1 round-robin: 3 consecutive `GET /api/health` via proxy return 3
  different backend ports.
- A2 timeline: `GET /api/timeline` via proxy returns seeded tweets
  newest-first with the exact F1 schema.
- A3 shared state: `POST /api/tweets` via proxy → tweet visible in a timeline
  fetched via proxy from a DIFFERENT backend (WAL sharing proven).
- A4 balance: `/lb-stats` total equals forwarded request count; after a load
  stand run every backend is within 10% of the mean.
- A5 self-contained UI: `GET /` HTML references no external URLs and contains
  the dark X layout (nav rail, compose box, tweet cards).
- A6 visual: screenshot of `/` at 1280×800 passes a golden screenshot eval —
  dark bg, left nav rail, center column with compose box and ≥3 tweet cards
  visible. Eval tools available at `../../evals/`:
  `snap <url> <out.png> [w h]`, `evalshot <shot.png> <golden.png> [thr]`,
  `apieval <url> <query.jq> <golden.toon>`.
- A7 checks: every component ships executable `check.sh` per Hard constraints.

## Out of scope
Auth, like/retweet actions, user profiles, pagination, websockets, media
uploads, persistence beyond the single sqlite file.
