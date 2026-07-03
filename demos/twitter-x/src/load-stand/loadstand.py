#!/usr/bin/env python3
"""Load stand: hammer proxy with ~80% GET /api/timeline / 20% POST /api/tweets,
then check /lb-stats balance. stdlib only.

Exit 0 iff every backend count within 10% of mean; else nonzero.
"""
import argparse
import json
import threading
import time
import urllib.error
import urllib.request


def worker(base, plan, next_i, lock, latencies):
    while True:
        with lock:
            if next_i[0] >= len(plan):
                return
            i = next_i[0]
            next_i[0] += 1
        is_post = plan[i]
        if is_post:
            req = urllib.request.Request(
                base + "/api/tweets",
                data=json.dumps({"text": f"load-stand tweet {i}"}).encode(),
                headers={"Content-Type": "application/json"}, method="POST")
        else:
            req = urllib.request.Request(base + "/api/timeline")
        t0 = time.monotonic()
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                r.read()
        except (urllib.error.URLError, OSError):
            pass  # counted server-side (or not, on 502) either way
        with lock:
            latencies.append(time.monotonic() - t0)


def pctl(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    k = min(len(sorted_vals) - 1, int(round(p / 100 * (len(sorted_vals) - 1))))
    return sorted_vals[k]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--requests", type=int, default=300)
    ap.add_argument("--concurrency", type=int, default=10)
    ap.add_argument("--url", required=True, help="proxy base, e.g. http://127.0.0.1:8080")
    args = ap.parse_args()
    base = args.url.rstrip("/")

    plan = [i % 5 == 0 for i in range(args.requests)]  # 20% POST
    next_i, lock, latencies = [0], threading.Lock(), []
    t0 = time.monotonic()
    threads = [threading.Thread(target=worker, args=(base, plan, next_i, lock, latencies))
               for _ in range(args.concurrency)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    elapsed = time.monotonic() - t0

    with urllib.request.urlopen(base + "/lb-stats", timeout=10) as r:
        stats = json.load(r)

    counts = [b["requests"] for b in stats["backends"]]
    mean = sum(counts) / len(counts) if counts else 0
    lat = sorted(latencies)
    print(f"requests={args.requests} concurrency={args.concurrency} elapsed={elapsed:.2f}s")
    print(f"req/s={args.requests / elapsed:.1f}")
    print(f"latency p50={pctl(lat, 50)*1000:.1f}ms p95={pctl(lat, 95)*1000:.1f}ms")
    for b in stats["backends"]:
        dev = abs(b["requests"] - mean) / mean if mean else float("inf")
        print(f"backend {b['port']}: requests={b['requests']} deviation={dev:.1%}")
    print(f"total={stats['total']} mean={mean:.1f}")

    if mean <= 0:
        print("BALANCE: FAIL (no traffic recorded)")
        raise SystemExit(2)
    if all(abs(c - mean) / mean <= 0.10 for c in counts):
        print("BALANCE: OK (all backends within 10% of mean)")
        raise SystemExit(0)
    print("BALANCE: FAIL (backend outside 10% of mean)")
    raise SystemExit(2)


if __name__ == "__main__":
    main()
