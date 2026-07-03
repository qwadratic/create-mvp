#!/usr/bin/env python3
"""Round-robin reverse proxy. stdlib only.

Usage: proxy.py [listen_port] [backend_port ...]
Defaults: 8080 -> 9101 9102 9103. listen_port 0 = pick free port.
Prints "PROXY_PORT=<port>" on stdout when ready.
"""
import http.client
import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade",
}


class LB:
    def __init__(self, ports):
        self.ports = ports
        self.counts = {p: 0 for p in ports}
        self.idx = 0
        self.lock = threading.Lock()

    def next_port(self):
        with self.lock:
            p = self.ports[self.idx]
            self.idx = (self.idx + 1) % len(self.ports)
            return p

    def hit(self, port):
        with self.lock:
            self.counts[port] += 1

    def stats(self):
        with self.lock:
            backends = [{"port": p, "requests": self.counts[p]} for p in self.ports]
            return {"backends": backends, "total": sum(self.counts.values())}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    lb = None  # set at startup

    def log_message(self, *a):
        pass

    def _send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _proxy(self):
        if self.path == "/lb-stats":
            self._send_json(200, self.lb.stats())
            return
        port = self.lb.next_port()
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in HOP_BY_HOP}
        try:
            conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
            conn.request(self.command, self.path, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            conn.close()
        except OSError:
            self._send_json(502, {"error": "bad gateway",
                                  "backend": port})
            return
        self.lb.hit(port)
        self.send_response(resp.status, resp.reason)
        for k, v in resp.getheaders():
            if k.lower() in HOP_BY_HOP or k.lower() == "content-length":
                continue
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Backend", str(port))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = _proxy


def main():
    listen = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    ports = [int(p) for p in sys.argv[2:]] or [9101, 9102, 9103]
    Handler.lb = LB(ports)
    srv = ThreadingHTTPServer(("127.0.0.1", listen), Handler)
    print(f"PROXY_PORT={srv.server_address[1]}", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
