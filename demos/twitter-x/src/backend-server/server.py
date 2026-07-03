#!/usr/bin/env python3
"""twitter-x backend instance. stdlib only.

Usage: server.py [port] [db-path] [ui-html-path]
Env fallbacks: PORT, DB_PATH, UI_HTML.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "db-seed"))
import seed  # noqa: E402

FIELDS = ("id", "handle", "name", "avatar_color", "text", "ts",
          "replies", "retweets", "likes")

PLACEHOLDER_HTML = "<!doctype html><html><body>twitter-x backend (UI file not found)</body></html>"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/health":
            self._send(200, {"ok": True, "port": self.server.server_address[1]})
        elif path == "/api/timeline":
            conn = seed.connect(self.server.db_path)
            try:
                rows = conn.execute(
                    "SELECT id, handle, name, avatar_color, text, ts, "
                    "replies, retweets, likes FROM tweets "
                    "ORDER BY id DESC LIMIT 50").fetchall()
            finally:
                conn.close()
            self._send(200, {"tweets": [dict(zip(FIELDS, r)) for r in rows]})
        elif path == "/":
            try:
                with open(self.server.ui_path, "rb") as f:
                    html = f.read()
            except OSError:
                html = PLACEHOLDER_HTML.encode()
            self._send(200, html, "text/html; charset=utf-8")
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/tweets":
            self._send(404, {"error": "not found"})
            return
        n = int(self.headers.get("Content-Length") or 0)
        try:
            payload = json.loads(self.rfile.read(n).decode() or "{}")
        except (ValueError, UnicodeDecodeError):
            self._send(400, {"error": "invalid JSON"})
            return
        text = payload.get("text")
        if not isinstance(text, str) or not text.strip() or len(text) > 280:
            self._send(400, {"error": "text required, 1-280 chars"})
            return
        conn = seed.connect(self.server.db_path)
        try:
            cur = conn.execute(
                "INSERT INTO tweets (handle, name, avatar_color, text, ts, "
                "replies, retweets, likes) VALUES (?,?,?,?,?,0,0,0)",
                ("you", "You", "#1d9bf0", text, "now"))
            conn.commit()
            row = conn.execute(
                "SELECT id, handle, name, avatar_color, text, ts, "
                "replies, retweets, likes FROM tweets WHERE id=?",
                (cur.lastrowid,)).fetchone()
        finally:
            conn.close()
        self._send(201, dict(zip(FIELDS, row)))


def main():
    port = int(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PORT", "0"))
    db_path = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("DB_PATH", "twitter.db")
    ui_path = sys.argv[3] if len(sys.argv) > 3 else os.environ.get(
        "UI_HTML", os.path.join(HERE, "..", "ui-page", "index.html"))

    # ensure schema exists (idempotent; seeding itself is run.sh's job)
    conn = seed.connect(db_path)
    conn.execute(seed.SCHEMA)
    conn.commit()
    conn.close()

    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    srv.db_path = db_path
    srv.ui_path = ui_path
    print(f"BACKEND_PORT={srv.server_address[1]}", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
