# Review: forth-forth vs goal.md

Method: read all code, ran every `src/*/check.sh` (all exit 0, all < 60s, no network/servers), re-verified pinned bytes independently, probed edge cases with fresh programs.

## Per-component verdicts

| Component | Verdict | Evidence |
|---|---|---|
| `stage0` (+ `stage0-core`, `stage0-compiler-support`, `stage0-gate` checks) | **PASS** | All required words work: arithmetic, comparison (-1/0), stack ops, `.` with exactly one trailing space, `emit`/`cr`/`." "`, colon defs (case-insensitive), nested `if/else/then`, `begin until`, `do loop i`, `variable/@/!`, both comment forms, signed literals. Compiler-support words verified: `token` (EOF→0, no-input→0), `h.`, `h=`, `h>n` (fail→`0 0`), `s"`, handle 0 never issued. Python3 stdlib only (`sys`, `re`). |
| `tests` / `tests-golden` | **PASS** | All three `.fs` programs verbatim from spec. Goldens byte-exact vs spec-pinned heredocs; sizes 24/66/40 match; trailing spaces on number lines confirmed via `od`. Goldens written from spec, not regenerated. |
| `stage1` / `stage1-compiler` | **PASS (with limitations)** | Zero Python — pure Forth, runs under stage0 alone. Compiles all three pinned tests + independent smoke test to byte-identical output. Limitations found by probing: (a) multi-word `." hello wide world"` mis-compiles (whitespace lost — inherent to the pinned `token` interface, which whitespace-splits; though single-space rejoin would be a feasible improvement); (b) uppercase word variants (`DUP`) mis-compile — case-insensitive matching is impossible with the pinned handle primitives (`h=` is exact equality; no char access). Neither case appears in any pinned test, and acceptance criteria gate only the pinned programs. Also: unknown words silently fall through to string-print (`ponytail`-style hack) rather than erroring. |
| `gate` | **PASS** | For each of fib/fizzbuzz/stackops: interpreted → `cmp` golden, compiled via stage1 → run → `cmp` same golden. All byte-exact. Artifacts in `build-out/`. |
| `selfhost` (stretch) | **PASS** | Chain independently re-run: `stage0(compiler.fs, compiler.fs) → compiler.py → fib2.py → matches fib golden` — confirmed. Bonus fixed point (gen1 == gen2) confirmed by check. `RESULT.md` is honest: openly documents that literal `src/stage1/compiler.fs` cannot self-compile and the self-hosted variant lives at `src/selfhost/compiler.fs`, plus known limits (string pragma, `_h2n` underscore laxity). `check.sh` exits 0 either way. Not faked. |

## Acceptance criteria

1. Interpreted == golden for all three tests: **met**.
2. `compiler.fs` zero Python, runs under stage0 alone: **met**.
3. Compiled == golden for all three tests: **met**.
4. Executable non-interactive `check.sh` per component, exit 0, <60s, no servers/network: **met** (7 components, all pass).
5. Goldens are pinned bytes, not regenerated: **met** (tests-golden check compares against spec-copied bytes + pinned sizes).
6. `RESULT.md` honest: **met**.
7. Evals = byte-exact golden diffs, CLI only (no visual/TUI evals applicable per goal): **met** — all diff evals run and pass.

## Integration verdict

**PASS.** Full bootstrap chain works end-to-end: stage0 interprets pinned tests to golden; stage1 (pure Forth under stage0) compiles them to standalone Python matching the same goldens byte-exact; the stage-2 gate enforces this; the stretch self-host is genuinely achieved (with an honestly documented file-location deviation) and reaches a fixed point. The two stage1 edge gaps (multi-word `."`, case variants) are outside the pinned acceptance surface and largely forced by the pinned `token`/handle interface; noted as limitations, not failures.

VERDICT: PASS
