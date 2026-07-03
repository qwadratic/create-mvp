#!/usr/bin/env python3
"""Deterministic idempotent sqlite seeder for twitter-x. stdlib only.

Usage: python3 seed.py <db-path>
Importable: connect(path), seed(path)
"""
import sqlite3
import sys

SCHEMA = """
CREATE TABLE IF NOT EXISTS tweets (
    id           INTEGER PRIMARY KEY,
    handle       TEXT NOT NULL,
    name         TEXT NOT NULL,
    avatar_color TEXT NOT NULL,
    text         TEXT NOT NULL,
    ts           TEXT NOT NULL,
    replies      INTEGER NOT NULL DEFAULT 0,
    retweets     INTEGER NOT NULL DEFAULT 0,
    likes        INTEGER NOT NULL DEFAULT 0
);
"""

# fixed ids -> INSERT OR IGNORE makes re-seeding a no-op
SEED_TWEETS = [
    # (id, handle, name, avatar_color, text, ts, replies, retweets, likes)
    (1, "elonrusk", "Elon Rusk", "#1d9bf0",
     "Shipping the new algorithm next week. It's going to be wild.",
     "Jul 1", 4821, 9210, 88400),
    (2, "sundarp", "Sundar P.", "#00ba7c",
     "AI will change how we search, code, and create. Excited for what's next.",
     "Jun 30", 812, 2100, 15300),
    (3, "gvanrossum", "Guido van Rossum", "#f91880",
     "Reminder: readability counts. Your future self will thank you.",
     "5h", 233, 1400, 9800),
    (4, "dan_abramov", "Dan Abramov", "#ffd400",
     "Hot take: most state doesn't need to be global. Keep it close to where it's used.",
     "3h", 156, 640, 5200),
    (5, "elonrusk", "Elon Rusk", "#1d9bf0",
     "Rockets are just servers that scale vertically.",
     "2h", 3100, 7800, 61000),
    (6, "gvanrossum", "Guido van Rossum", "#f91880",
     "There should be one-- and preferably only one --obvious way to do it.",
     "1h", 98, 870, 6400),
    (7, "sundarp", "Sundar P.", "#00ba7c",
     "Great teams ship. Even better teams ship and then listen.",
     "45m", 64, 310, 2900),
    (8, "dan_abramov", "Dan Abramov", "#ffd400",
     "Wrote a reverse proxy in pure stdlib today. Felt good.",
     "12m", 41, 120, 1800),
]


def connect(path):
    """Open sqlite connection with WAL + busy_timeout per PRD."""
    conn = sqlite3.connect(path, timeout=5)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=2000")
    return conn


def seed(path):
    conn = connect(path)
    try:
        conn.execute(SCHEMA)
        conn.executemany(
            "INSERT OR IGNORE INTO tweets "
            "(id, handle, name, avatar_color, text, ts, replies, retweets, likes) "
            "VALUES (?,?,?,?,?,?,?,?,?)",
            SEED_TWEETS,
        )
        conn.commit()
        return conn.execute("SELECT COUNT(*) FROM tweets").fetchone()[0]
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: seed.py <db-path>")
    n = seed(sys.argv[1])
    print(f"seeded: {n} tweets in {sys.argv[1]}")
