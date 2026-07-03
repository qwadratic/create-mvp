import json
import os
import subprocess
import sys
import tempfile
from datetime import date

CLI = os.path.join(os.path.dirname(__file__), "cli.py")


def run(args, env):
    return subprocess.run([sys.executable, CLI] + args,
                          capture_output=True, text=True, env=env)


with tempfile.TemporaryDirectory() as d:
    path = os.path.join(d, "habits.json")
    env = dict(os.environ, HABITS_FILE=path)

    # add
    r = run(["add", "read"], env)
    assert r.returncode == 0, r.stderr
    assert "added: read" in r.stdout

    # dup add -> nonzero + message
    r = run(["add", "read"], env)
    assert r.returncode == 1
    assert "duplicate" in r.stderr

    # done
    r = run(["done", "read"], env)
    assert r.returncode == 0, r.stderr
    assert "done: read" in r.stdout

    # dup done same day -> nonzero
    r = run(["done", "read"], env)
    assert r.returncode == 1
    assert "already" in r.stderr

    # unknown habit -> nonzero + message
    r = run(["done", "nope"], env)
    assert r.returncode == 1
    assert "unknown habit" in r.stderr

    # data file persisted
    data = json.load(open(path))
    assert data == {"read": [date.today().isoformat()]}, data

    # --render
    r = run(["--render"], env)
    assert r.returncode == 0, r.stderr
    assert "read" in r.stdout and "[x]" in r.stdout

    # no args -> usage, nonzero
    r = run([], env)
    assert r.returncode == 2

print("cli-commands: all tests passed")
