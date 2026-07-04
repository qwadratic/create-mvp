# Evals: how agent output gets verified

Agents lie confidently, so nothing in a create-mvp pipeline counts as done
until a mechanical check says so. All eval tools live in [`evals/`](../evals/)
and share one design: exit code is the verdict, so any of them can sit on a
recipe line and gate a target (a failing check fails the recipe, and
`.DELETE_ON_ERROR` discards the artifact — see
[engine-internals.md](engine-internals.md)).

## The toolbox

| tool | checks | fires when |
|---|---|---|
| [`evals/snap`](../evals/snap) | renders HTML → lowres PNG (~0.2 s/shot) | a component's `check.sh` needs a screenshot of visual output |
| [`evals/evalshot`](../evals/evalshot) | screenshot vs. golden PNG via ffmpeg SSIM (default threshold 0.97) | right after `snap`, same `check.sh` — visual regression gate |
| [`evals/apieval`](../evals/apieval) | live JSON API vs. golden: `curl → jq reshape → TOON encode → diff` | a component exposes an HTTP/JSON endpoint |
| TUI goldens ([`evals/docs/TUI.md`](../evals/docs/TUI.md)) | terminal grid via `tmux capture-pane` vs. text golden | the built thing is a TUI (see [`demos/tui-habits/evals/tui-check.sh`](../demos/tui-habits/evals/tui-check.sh)) |
| [`evals/wfcheck`](../evals/wfcheck) | a whole engine run: plan schema, DAG validity, per-component src + `check.sh` re-runs, `.done` census, review verdict → `build/wfscore.json` | after a pipeline finishes — did the *workflow* behave, not just the code |
| [`evals/matrix`](../evals/matrix) | same fixed goal through the engine per model; collects wfcheck score, wall time, tokens/cost → [`evals/matrix-results.md`](../evals/matrix-results.md) | comparing models / validating engine changes across providers |

Rough layering: `snap`/`evalshot`/`apieval`/TUI goldens gate **individual
components** during a build; `wfcheck` grades **one finished run**; `matrix`
runs **many builds** to grade the engine itself.

## snap + evalshot: visual gates

`snap` renders natively at the target low resolution (480×640 by default) —
faster and smaller than rendering big and downscaling (measurements in
[`evals/docs/BENCH.md`](../evals/docs/BENCH.md)). `evalshot` compares against a
committed golden PNG and, on failure, writes `<shot>.diff.png` where bright
pixels mark the mismatch. It refuses dimension mismatches loudly rather than
rescaling, so viewport drift can't hide.

Typical `check.sh` tail:

```bash
../../evals/snap "http://localhost:$PORT/eval.html" shots/eval.png 480 640
../../evals/evalshot shots/eval.png golden/eval.png
```

Threshold guidance and flaky-render mitigation (frozen animations, font
settling, masked timestamps) live in
[`evals/docs/EVAL-PATTERNS.md`](../evals/docs/EVAL-PATTERNS.md).

## apieval: JSON goldens without the flakiness

Raw JSON diffs break on key order and volatile fields. `apieval` normalizes
first: a `.jq` query file reshapes the response (sort keys with `-S`, strip
timestamps/ids, keep only what matters), then the result is encoded as
[TOON](https://toonformat.dev) before diffing. TOON goldens declare
keys once and stream rows, so they line-diff cleanly and stay cheap for agents
to read back into context. `toon -d <golden>` recovers plain JSON when you
want to inspect one.

```bash
evals/apieval http://localhost:8080/api/timeline evals/timeline.jq goldens/timeline.toon
```

## TUI goldens: text, not pixels

A terminal is already a deterministic character grid — capture it as text and
`diff -u` is the whole eval report. `tmux capture-pane -p` into a fixed 80×24
session, poll for a readiness marker (never bare `sleep`), strip trailing
whitespace, diff against a committed `.txt` golden. Full recipe, determinism
gotchas, and the multi-frame interaction pattern (`send-keys` then re-capture)
are in [`evals/docs/TUI.md`](../evals/docs/TUI.md).

## Golden update protocol

One rule: **a failing eval never auto-updates its golden.**

- **First run** — no golden exists yet: `evalshot` and `apieval` seed it from
  the current output, print a loud NOTE, and auto-pass. Review the seeded
  golden by eye, then commit it. TUI goldens regenerate explicitly via
  `UPDATE_GOLDEN=1`.
- **Regression** (the normal failure): look at the diff (`.diff.png`, TOON
  diff, or text diff), fix the code until the eval passes. Golden untouched.
- **Intentional change**: eyeball the new output — that *is* the review —
  then delete the golden and rerun to re-seed (or `UPDATE_GOLDEN=1` for TUI).
  Commit the new golden **in the same commit** as the change that caused it,
  with a message saying why. A golden changing in an unrelated commit is a
  review red flag; `git log --stat -- '*golden*'` is the audit trail.

In the agent loop, builder agents receive eval failures as fix-loop feedback
but are never given "delete the golden" as an action — otherwise every
regression becomes an "intentional change". Only the reviewer gate or a human
retires a golden.
