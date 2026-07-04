# forth-forth — Forth compiler written in Forth, built by agentmake

A Forth compiler that is itself a Forth program, bootstrapped in stages by
the agentmake engine from a single `goal.md`. Stretch goal reached: **the
compiler compiles itself, byte-exact fixed point (gen1 output == gen2)**.

```
goal.md ──▶ classify (prd tier) ──▶ plan (7 components) ──▶ build agents ──▶ review: PASS
```

## The prompt trick: staged bootstrap encoded in the PRD

The interesting part is not the code — it's how `goal.md` is written so LLM
build agents pull off a compiler bootstrap without a human in the loop:

1. **Stages as components.** The PRD hard-splits the impossible ask ("Forth
   compiler in Forth") into three stages with a dependency arrow: stage0 =
   seed interpreter (Python), stage1 = compiler *in Forth run by stage0*,
   stage2 = equivalence gate. Each stage is independently checkable, so the
   engine's DAG scheduling does the bootstrap ordering for free.
2. **The interface is the spec.** The PRD pins the exact compiler-support
   words (`token`, `h.`, `h=`, `h>n`, `s"` — string *handles* on an integer
   stack) that stage0 must provide and stage1 may consume. Two agents built
   the two sides without talking; the pinned word contract is the only
   channel.
3. **Goldens pinned in the PRD, not generated.** Test programs AND their
   exact output bytes (down to `.`'s trailing space) are written into
   `goal.md`, with an explicit "do not regenerate goldens from program
   output" clause. Agents can't game the gate; interpreted == compiled ==
   pinned-bytes is the proof.
4. **Stretch isolated + honesty clause.** Self-hosting lives in its own
   component whose `check.sh` must exit 0 *either way* and write the honest
   outcome to `RESULT.md` ("Do not fake it."). Failure can't wedge the build;
   success can't be bluffed — the reviewer re-runs the chain.

## Result

- **First run, zero retry loops.** All 7 components green, review `VERDICT: PASS`,
  `wfcheck: PASS 32/32 (score 1)`.
- Stage0: ~190-line stdlib Python Forth (nested `if/else/then`, `begin/until`,
  `do/loop/i`, variables, both comment styles, string-handle words).
- Stage1: `src/stage1/compiler.fs` — zero Python, run by stage0, emits
  standalone Python with embedded runtime. fib/fizzbuzz/stackops compile to
  byte-exact golden matches.
- Selfhost: `src/selfhost/compiler.fs` (stage1 extended so its emitted runtime
  also carries the string table + `token`) compiles itself; the self-compiled
  compiler compiles fib to a golden match, and gen1 == gen2 byte-identical.
  Honest deviations recorded in `src/selfhost/RESULT.md` (e.g. multi-word
  `." ..."` strings can't survive whitespace tokenization — the PRD's `token`
  is deliberately minimal).

## Run it

```sh
make            # full pipeline (needs pi CLI); resumes wherever it stopped
make progress   # census
bash src/gate/check.sh        # stage-2 equivalence gate
bash src/selfhost/check.sh    # self-hosting chain
../../evals/wfcheck .         # workflow-correctness score
```

Post-build evolution: a live pi agent, restricted to the single `forth` tool
from `../../demoscene/forth-tool`, added a 4th golden test
(`src/tests/sierpinski.fs`, Sierpinski triangle via Lucas' theorem — no
bitwise words in the dialect); recording + trace in `../../demoscene/`
(`session.cast`, `session-trace.jsonl`, `SESSION.md`).

Artifacts: `buildlog.txt` (full engine run), `shots/` (progress, gate,
selfhost fixed point, dep graph), `REVIEW.md` + `build/report.md` (reviewer),
`build/wfscore.json`.
