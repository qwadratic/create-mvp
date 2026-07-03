#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

TMPDIR_DB="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_DB"' EXIT
DB="$TMPDIR_DB/tweets.db"

# seed twice -> idempotent
python3 seed.py "$DB" >/dev/null
C1=$(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT COUNT(*) FROM tweets').fetchone()[0])" "$DB")
python3 seed.py "$DB" >/dev/null
C2=$(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT COUNT(*) FROM tweets').fetchone()[0])" "$DB")

[ "$C1" = "$C2" ] || { echo "FAIL: row count changed on re-seed ($C1 -> $C2)"; exit 1; }
[ "$C1" -ge 8 ] || { echo "FAIL: expected >=8 tweets, got $C1"; exit 1; }

python3 - "$DB" <<'EOF'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])

# schema fields
cols = {r[1] for r in db.execute("PRAGMA table_info(tweets)")}
need = {"id","handle","name","avatar_color","text","ts","replies","retweets","likes"}
missing = need - cols
assert not missing, f"missing columns: {missing}"

# WAL mode persisted in DB file
mode = db.execute("PRAGMA journal_mode").fetchone()[0]
assert mode.lower() == "wal", f"journal_mode={mode}, expected wal"

rows = db.execute("SELECT handle, avatar_color, ts, replies, retweets, likes FROM tweets").fetchall()
users = {r[0] for r in rows}
assert len(users) >= 4, f"expected >=4 users, got {len(users)}"

# distinct avatar color per user
colors = {r[0]: r[1] for r in rows}
assert len(set(colors.values())) == len(colors), "avatar colors not distinct per user"

# fixed ts strings + non-zero counts
for h, c, ts, rp, rt, lk in rows:
    assert ts and isinstance(ts, str), "ts must be non-empty string"
    assert rp > 0 and rt > 0 and lk > 0, f"zero engagement count on @{h}"

# connect() from module applies WAL + busy_timeout>=2000
sys.path.insert(0, ".")
import seed
conn = seed.connect(sys.argv[1])
assert conn.execute("PRAGMA journal_mode").fetchone()[0].lower() == "wal"
assert conn.execute("PRAGMA busy_timeout").fetchone()[0] >= 2000
conn.close()
print("OK: schema, WAL, busy_timeout, idempotent seed, %d tweets / %d users" % (len(rows), len(users)))
EOF
