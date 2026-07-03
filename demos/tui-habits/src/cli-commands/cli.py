"""cli-commands: argparse CLI wiring store + view. add NAME, done NAME, --render."""
import argparse
import os
import sys
from datetime import date

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "habit-store"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "render-view"))
import store  # noqa: E402
from view import render  # noqa: E402


def main(argv=None):
    p = argparse.ArgumentParser(prog="habits", description="terminal habit tracker")
    p.add_argument("--render", action="store_true", help="print streak table")
    sub = p.add_subparsers(dest="cmd")
    sub.add_parser("add").add_argument("name")
    sub.add_parser("done").add_argument("name")
    args = p.parse_args(argv)

    habits = store.load()
    today = date.today().isoformat()

    if args.render:
        print(render(habits, today), end="")
        return 0
    if args.cmd == "add":
        try:
            store.add_habit(habits, args.name)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 1
        store.save(habits)
        print(f"added: {args.name}")
        return 0
    if args.cmd == "done":
        try:
            store.mark_done(habits, args.name, today)
        except (KeyError, ValueError) as e:
            msg = e.args[0] if e.args else e
            print(f"error: {msg}", file=sys.stderr)
            return 1
        store.save(habits)
        print(f"done: {args.name} ({today})")
        return 0
    p.print_help(sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
