# forth-forth — a Forth compiler written in Forth (staged bootstrap)

Build a Forth toolchain where the compiler is itself a Forth program. The trick
is a staged bootstrap: a tiny seed interpreter (Python) runs a compiler written
in Forth, and every stage is gated by byte-exact golden outputs.

Tech constraints: python3 stdlib ONLY. No pip, no network, no docker, no
external services. Integer cells only (no floats). Everything non-interactive.
All code under `src/`.

## Stage 0 — seed interpreter (Python)

`src/stage0/stage0.py` — minimal Forth interpreter, python3 stdlib only.
Usage: `python3 src/stage0/stage0.py <prog.fs> [input.fs]`.

Required words (space-separated tokens, case-insensitive, data stack of ints):

- arithmetic: `+ - * / mod negate`
- comparison: `= < >` (true is -1, false is 0)
- stack: `dup drop swap over rot`
- output: `.` prints top as decimal followed by EXACTLY ONE space (no newline);
  `emit` prints char; `cr` prints newline; `." text"` prints literal text as-is
- definitions: `: name ... ;`
- control flow (inside colon definitions, nesting required): `if else then`,
  `begin until`, `do loop i` (`do` takes `limit start`, `i` pushes loop index)
- variables: `variable name` (name pushes address), `@` fetch, `!` store
- comments: `\ to end of line` and `( inline )`
- number literals: optionally signed decimal integers

Compiler-support words (strings live in an interpreter-side string table; the
data stack carries integer HANDLES; handle 0 is never valid):

- `token ( -- h|0 )` next whitespace-delimited token read from the INPUT file
  (`input.fs`, second argv), 0 at EOF
- `h. ( h -- )` print the handle's string, no newline
- `h= ( h1 h2 -- f )` string equality of two handles
- `h>n ( h -- n f )` try to parse handle as integer: `n -1` on success, `0 0` on failure
- `s" text"` push literal string as a handle (works inside and outside definitions)

## Stage 1 — the compiler, written in Forth

`src/stage1/compiler.fs` — a Forth program (ZERO Python inside this file),
executed BY stage0, that reads Forth source via `token` and writes an
equivalent standalone Python program to stdout:

    python3 src/stage0/stage0.py src/stage1/compiler.fs prog.fs > prog.py
    python3 prog.py     # byte-identical output to stage0 interpreting prog.fs

The emitted Python is self-contained: the compiler first prints a small runtime
preamble (stack + word implementations), then the compiled program. The
compiler must handle every Stage 0 word EXCEPT the compiler-support words —
compiled test programs never use `token`/`h.`/`h=`/`h>n`.

## Stage 2 — gate: interpreted == compiled == golden

`src/tests/` holds three test programs and their goldens. Programs and expected
bytes are PINNED below — copy them verbatim. Goldens are the exact bytes shown
(note: `.` emits a trailing space, so number-lines end in one space).

`src/tests/fib.fs`:

```forth
\ first 10 fibonacci numbers on one line
: fib10  0 1 10 0 do over . swap over + loop drop drop ;
fib10 cr
```

`src/tests/golden/fib.out` (one line): `0 1 1 2 3 5 8 13 21 34 ` + newline

`src/tests/fizzbuzz.fs`:

```forth
: fizzbuzz
  16 1 do
    i 15 mod 0 = if ." FizzBuzz" else
    i 3 mod 0 = if ." Fizz" else
    i 5 mod 0 = if ." Buzz" else
    i . then then then cr
  loop ;
fizzbuzz
```

`src/tests/golden/fizzbuzz.out` — 15 lines: `1 `, `2 `, `Fizz`, `4 `, `Buzz`,
`Fizz`, `7 `, `8 `, `Fizz`, `Buzz`, `11 `, `Fizz`, `13 `, `14 `, `FizzBuzz`
(number lines carry the trailing space, word lines do not).

`src/tests/stackops.fs`:

```forth
1 2 3 rot . . . cr
4 5 swap . . cr
6 dup + . cr
7 8 over . . . cr
10 3 - . 10 3 mod . 2 3 * . cr
5 5 = . 3 5 < . 5 3 > . cr
```

`src/tests/golden/stackops.out` — 6 lines: `1 3 2 `, `4 5 `, `12 `, `7 8 7 `,
`7 1 6 `, `-1 -1 -1 ` (every line ends in one space).

The stage-2 gate component (`src/gate/check.sh`) must, for EACH test program:
1. run it interpreted: `python3 src/stage0/stage0.py src/tests/<t>.fs` → diff golden
2. compile it: `python3 src/stage0/stage0.py src/stage1/compiler.fs src/tests/<t>.fs > build-out/<t>.py`
3. run compiled: `python3 build-out/<t>.py` → diff same golden
Byte-exact `diff` or `cmp` — any mismatch fails.

## STRETCH (attempt, must not block the build)

Self-hosting: stage1 compiles ITSELF. Requires the emitted runtime to also
implement the compiler-support words (string table, `token` reading argv[1]):

    python3 src/stage0/stage0.py src/stage1/compiler.fs src/stage1/compiler.fs > compiler.py
    python3 compiler.py src/tests/fib.fs > fib2.py   # then fib2.py matches fib golden

Put this in its own component (`selfhost`). Its `check.sh` MUST exit 0 either
way and write the honest outcome (achieved / failed and WHY) to
`src/selfhost/RESULT.md`. Do not fake it.

## Acceptance criteria

1. `python3 src/stage0/stage0.py src/tests/<t>.fs` matches golden byte-exact
   for all three tests (fib, fizzbuzz, stackops).
2. `src/stage1/compiler.fs` contains zero Python; it runs under stage0 alone.
3. Compiled Python for all three tests matches the same goldens byte-exact
   (interpreted == compiled equivalence).
4. Every component ships an executable non-interactive `check.sh`: exits 0 on
   success, finishes under 60s, no servers, no network.
5. Goldens are the pinned bytes above — do not regenerate them from program
   output; write them from this spec.
6. `src/selfhost/RESULT.md` reports the self-compilation attempt honestly.
7. Evals for this project are byte-exact golden diffs (CLI only — no GUI, no
   visual/TUI evals applicable).

Suggested decomposition: `stage0` (interpreter), `tests` (pinned programs +
goldens), `stage1` (compiler.fs, deps: stage0 + tests), `selfhost` (stretch,
deps: stage1), `gate` (stage-2 equivalence gate, deps: stage0 + tests + stage1).
