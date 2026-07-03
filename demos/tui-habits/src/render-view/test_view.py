import json
import os
import subprocess
import sys
import tempfile

from view import render

TODAY = "2026-07-03"
FIX = {
    "read": ["2026-07-01", "2026-07-02", "2026-07-03"],
    "run": ["2026-06-28", "2026-06-29"],
}

out = render(FIX, TODAY)
assert "read" in out and "run" in out
assert "[x]" in out and "[ ]" in out
assert "habit" in out and "streak" in out and "best" in out
# read: current 3, best 3; run: current 0, best 2
read_line = next(l for l in out.splitlines() if l.startswith("read"))
run_line = next(l for l in out.splitlines() if l.startswith("run"))
assert "3" in read_line and "[x]" in read_line
assert "0" in run_line and "2" in run_line and "[ ]" in run_line
assert render({}, TODAY) == "no habits yet\n"

# CLI --render
with tempfile.TemporaryDirectory() as d:
    path = os.path.join(d, "habits.json")
    with open(path, "w") as f:
        json.dump(FIX, f)
    env = dict(os.environ, HABITS_FILE=path)
    r = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "view.py"),
                        "--render"], capture_output=True, text=True, env=env)
    assert r.returncode == 0, r.stderr
    assert "read" in r.stdout and "run" in r.stdout

print("render-view: all tests passed")
