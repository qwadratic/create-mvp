"""tui-loop: interactive curses habit screen. Logic separated from curses I/O.

Keys: j/k navigate, space toggles done-today, a adds habit (prompt), q quits.
"""
import os
import sys
from datetime import date

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "habit-store"))
sys.path.insert(0, os.path.join(_HERE, "..", "streak-logic"))
sys.path.insert(0, os.path.join(_HERE, "..", "render-view"))
import store  # noqa: E402
import view  # noqa: E402
from streaks import best_streak, current_streak  # noqa: E402


# ---------- pure state + key logic (testable without curses) ----------

def new_state(habits, today=None):
    return {
        "habits": habits,
        "today": today or date.today().isoformat(),
        "sel": 0,
        "quit": False,
        "msg": "",
    }


def names(state):
    return sorted(state["habits"])


def toggle_done(state):
    ns = names(state)
    if not ns:
        return
    name, today = ns[state["sel"]], state["today"]
    dates = state["habits"][name]
    if today in dates:
        dates.remove(today)
    else:
        dates.append(today)
        dates.sort()


def add_habit(state, name):
    try:
        store.add_habit(state["habits"], name)
        state["msg"] = f"added {name.strip()}"
    except ValueError as e:
        state["msg"] = str(e)


def handle_key(state, key, prompt=None):
    """key: str. prompt: callable() -> str, used for 'a'. Returns state."""
    state["msg"] = ""
    n = len(names(state))
    if key == "q":
        state["quit"] = True
    elif key == "j" and n:
        state["sel"] = min(state["sel"] + 1, n - 1)
    elif key == "k" and n:
        state["sel"] = max(state["sel"] - 1, 0)
    elif key == " ":
        toggle_done(state)
    elif key == "a" and prompt:
        name = prompt()
        if name:
            add_habit(state, name)
    return state


def build_rows(state):
    """List of (line, selected) tuples; shares streak/marker semantics with view."""
    rows = []
    today = state["today"]
    for i, name in enumerate(names(state)):
        dates = state["habits"][name]
        mark = "[x]" if today in dates else "[ ]"
        line = f"{mark} {name}  cur:{current_streak(dates, today)} best:{best_streak(dates)}"
        rows.append((line, i == state["sel"]))
    return rows


# ---------- curses I/O ----------

def _prompt(scr, text):
    import curses
    h, w = scr.getmaxyx()
    scr.addstr(h - 1, 0, text)
    curses.echo()
    s = scr.getstr(h - 1, len(text), 40).decode()
    curses.noecho()
    return s


def _loop(scr):
    import curses
    curses.curs_set(0)
    state = new_state(store.load())
    while not state["quit"]:
        scr.erase()
        scr.addstr(0, 0, "habits  (j/k move, space toggle, a add, q quit)")
        for i, (line, sel) in enumerate(build_rows(state)):
            scr.addstr(i + 2, 0, line, curses.A_REVERSE if sel else curses.A_NORMAL)
        if state["msg"]:
            scr.addstr(scr.getmaxyx()[0] - 1, 0, state["msg"])
        scr.refresh()
        key = scr.getkey()
        handle_key(state, key, prompt=lambda: _prompt(scr, "new habit: "))
    store.save(state["habits"])


def main():
    import curses
    curses.wrapper(_loop)


if __name__ == "__main__":
    main()
