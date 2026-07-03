#!/usr/bin/env bash
# run run.sh --check on freshly allocated free ports (safe under make -j).
set -euo pipefail
cd "$(dirname "$0")"

read -r B1 B2 B3 PROXY_PORT < <(python3 -c '
import socket
socks = [socket.socket() for _ in range(4)]
for s in socks: s.bind(("127.0.0.1", 0))
print(*[s.getsockname()[1] for s in socks])
for s in socks: s.close()')

export B1 B2 B3 PROXY_PORT
exec ./run.sh --check
