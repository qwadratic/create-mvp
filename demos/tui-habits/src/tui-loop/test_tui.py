"""Non-interactive self-test: drive key handlers without curses init."""
import tui

T = "2026-07-03"
state = tui.new_state({"read": ["2026-07-02"], "run": []}, today=T)

# names sorted
assert tui.names(state) == ["read", "run"]

# navigation clamps
tui.handle_key(state, "k")
assert state["sel"] == 0
tui.handle_key(state, "j")
assert state["sel"] == 1
tui.handle_key(state, "j")
assert state["sel"] == 1

# space toggles done-today on selected ("run")
tui.handle_key(state, " ")
assert T in state["habits"]["run"]
tui.handle_key(state, " ")
assert T not in state["habits"]["run"]

# add via prompt callable
tui.handle_key(state, "a", prompt=lambda: "meditate")
assert "meditate" in state["habits"]
assert state["msg"] == "added meditate"

# duplicate add -> message, no crash
tui.handle_key(state, "a", prompt=lambda: "meditate")
assert "duplicate" in state["msg"]

# rows: marker + streaks, selection flag
state["sel"] = 1  # "read"
rows = tui.build_rows(state)
assert rows[1][1] is True and rows[0][1] is False
read_line = rows[1][0]
assert read_line.startswith("[ ]") and "cur:1" in read_line and "best:1" in read_line
tui.handle_key(state, " ")  # mark read today
read_line = tui.build_rows(state)[1][0]
assert read_line.startswith("[x]") and "cur:2" in read_line and "best:2" in read_line

# quit
tui.handle_key(state, "q")
assert state["quit"] is True

# empty state: keys no-op safely
empty = tui.new_state({}, today=T)
tui.handle_key(empty, "j")
tui.handle_key(empty, " ")
assert empty["sel"] == 0 and empty["habits"] == {}

print("tui-loop: OK")
