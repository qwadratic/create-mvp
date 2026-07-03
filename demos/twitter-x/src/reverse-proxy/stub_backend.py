#!/usr/bin/env python3
"""Test stub backend: echoes port/method/path/body as JSON. Usage: stub_backend.py <port>"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _h(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n).decode() if n else ""
        out = json.dumps({"port": self.server.server_address[1],
                          "method": self.command, "path": self.path,
                          "body": body}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    do_GET = do_POST = _h


srv = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H)
print(f"STUB_PORT={srv.server_address[1]}", flush=True)
srv.serve_forever()
