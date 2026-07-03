# Review: tui-habits vs goal.md

Goal: terminal habit tracker — add habit, mark done today, streak view, python3 stdlib (curses or ANSI), non-interactive `--render` for testing.

## Per-component

| Component | Verdict | Notes |
|---|---|---|
| habit-store | PASS | JSON persistence, `HABITS_FILE` env override, validates empty/dup names, dup-date guard. check.sh green. |
| streak-logic | PASS | Pure functions; `current_streak` correctly allows unmarked-today grace (counts from yesterday); `best_streak` handles dedup/sort. check.sh green. |
| render-view | PASS | Plain-ANSI table with bold/green/dim, `--render` entry point works standalone. check.sh green. |
| cli-commands | PASS | `add NAME`, `done NAME`, `--render`; error paths return exit 1 with stderr message. check.sh green. |
| tui-loop | PASS | curses UI with logic (`handle_key`, `build_rows`, `toggle_done`) cleanly separated from I/O — testable without a terminal. j/k/space/a/q keys per docstring. check.sh green. Saves on quit only (acceptable shortcut for scope). |

## Checks

All 5 `src/*/check.sh` pass.

## Integration

Smoke test in temp dir with `HABITS_FILE`: `add exercise`, `add read`, `done read`, `--render` → correct table (`[x]`, streak 1/best 1 for read; `[ ]` 0/0 for exercise). Duplicate `add` rejected with exit 1. Standalone `view.py --render` also works. Modules share store/streak code via sys.path inserts — crude but consistent and functional. Stdlib only. Goal requirements (add, mark-done-today, streak view, curses + ANSI, non-interactive `--render`) all met.

Minor nits (non-blocking): curses `addstr` could throw on very small terminals; TUI persists only at quit.

VERDICT: PASS
