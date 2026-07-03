"""render-view: plain-ANSI table of habits with done marker + streaks."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "habit-store"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "streak-logic"))
import store  # noqa: E402
from streaks import best_streak, current_streak  # noqa: E402

BOLD, GREEN, DIM, RESET = "\033[1m", "\033[32m", "\033[2m", "\033[0m"


def render(habits, today):
    """habits: {name: [iso dates]}, today: iso string. Returns table string."""
    if not habits:
        return "no habits yet\n"
    rows = []
    for name in sorted(habits):
        dates = habits[name]
        done = today in dates
        rows.append((name,
                     f"{GREEN}[x]{RESET}" if done else f"{DIM}[ ]{RESET}",
                     str(current_streak(dates, today)),
                     str(best_streak(dates))))
    w = max(len(r[0]) for r in rows + [("habit", "", "", "")])
    out = [f"{BOLD}{'habit'.ljust(w)}  today  streak  best{RESET}"]
    for name, mark, cur, best in rows:
        out.append(f"{name.ljust(w)}  {mark}    {cur.rjust(6)}  {best.rjust(4)}")
    return "\n".join(out) + "\n"


def main(argv):
    if "--render" in argv:
        from datetime import date
        print(render(store.load(), date.today().isoformat()), end="")
        return 0
    print("usage: view.py --render", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
