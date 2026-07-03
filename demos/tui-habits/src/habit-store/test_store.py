import os
import tempfile

import store

path = os.path.join(tempfile.mkdtemp(), "habits.json")

# fresh load = empty
h = store.load(path)
assert h == {}

store.add_habit(h, "read")
store.add_habit(h, "run")
try:
    store.add_habit(h, "read")
    assert False, "dup name accepted"
except ValueError:
    pass

store.mark_done(h, "read", "2026-07-02")
store.mark_done(h, "read", "2026-07-03")
try:
    store.mark_done(h, "read", "2026-07-03")
    assert False, "dup date accepted"
except ValueError:
    pass
try:
    store.mark_done(h, "nope", "2026-07-03")
    assert False, "unknown habit accepted"
except KeyError:
    pass

store.save(h, path)

# reload, verify state persisted
h2 = store.load(path)
assert h2 == {"read": ["2026-07-02", "2026-07-03"], "run": []}, h2

print("habit-store: OK")
