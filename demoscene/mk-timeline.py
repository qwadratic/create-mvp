#!/usr/bin/env python3
"""session.cast + out/session.attn.json -> out/session-capped.cast + out/timeline.json

Maps each sidecar frame (tool-call moment) onto the *video* clock:
orig cast time -> idle-capped time -> /SPEED (agg --speed) = final.mp4 time.
Direct cast->grade coupling: drawtext/pulse enable-windows come from here.
stdlib only.
"""
import json, pathlib, datetime

HERE = pathlib.Path(__file__).parent
CAP = 1.0          # max inter-event gap kept (s)
SPEED = 2.3        # agg --speed
FPS = 30

# --- cap idle gaps, keep piecewise orig->capped mapping ----------------------
events, orig_cum, capped_cum = [], [0.0], [0.0]
with open(HERE / "session.cast") as f:
    header = json.loads(f.readline())
    t_o = t_c = 0.0
    for line in f:
        e = json.loads(line)
        d = e[0]
        t_o += d
        t_c += min(d, CAP)
        e[0] = min(d, CAP)
        events.append(e)
        orig_cum.append(t_o)
        capped_cum.append(t_c)

out = HERE / "out"
out.mkdir(exist_ok=True)
with open(out / "session-capped.cast", "w") as f:
    f.write(json.dumps(header, separators=(",", ":")) + "\n")
    for e in events:
        f.write(json.dumps(e, separators=(",", ":"), ensure_ascii=False) + "\n")

def to_video(t_orig):
    """orig cast seconds -> video seconds (binary-search piecewise + /SPEED)."""
    import bisect
    i = bisect.bisect_right(orig_cum, t_orig) - 1
    i = max(0, min(i, len(capped_cum) - 1))
    extra = min(t_orig - orig_cum[i], CAP)
    return (capped_cum[i] + max(0.0, extra)) / SPEED

epoch = header["timestamp"]
sidecar = json.loads((out / "session.attn.json").read_text())
assert sidecar["disclaimer"] == "interpretive proxy — not model internals", "reject sidecar"

def iso_s(ts):
    return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()

video_len = capped_cum[-1] / SPEED
HUE = {"def": 180, "ctl": -75, "stk": 60, "lit": 0, "com": 0, "usr": 120, "prim": 0}
CATNAME = {"def": "DEF", "ctl": "CTL", "stk": "STK", "lit": "LIT",
           "com": "COM", "usr": "USR", "prim": "PRIM"}

frames = sidecar["frames"]
starts = [round(to_video(iso_s(fr["ts"]) - epoch), 2) for fr in frames]
segments = [{"start": 0.0, "end": starts[0], "cat": None, "hue": 0, "heat": 0.0,
             "label": "session boot · prompt", "attn_label": None,
             "junction_pulses": []}]
for k, fr in enumerate(frames):
    s = starts[k]
    e = starts[k + 1] if k + 1 < len(frames) else round(video_len, 2)
    npulse = min(fr["decision_junctions"], 3)
    pulses = [round(s + 0.15 + j * 0.55, 2) for j in range(npulse)]
    heat = round(min(1.0, sum(fr["cat_weights"].values()) / 25.0), 3)
    segments.append({
        "start": s, "end": e,
        "cat": fr["dominant_cat"], "catname": CATNAME[fr["dominant_cat"]],
        "hue": HUE[fr["dominant_cat"]], "heat": heat,
        "label": f"frame {fr['idx']:02d} · forth · cat {CATNAME[fr['dominant_cat']]}",
        "attn_label": fr["attn_label"],
        "junctions": fr["decision_junctions"],
        "junction_pulses": pulses,
    })

timeline = {
    "disclaimer": sidecar["disclaimer"],
    "speed": SPEED, "idle_cap": CAP, "fps": FPS,
    "video_len": round(video_len, 2),
    "segments": segments,
}
(out / "timeline.json").write_text(json.dumps(timeline, ensure_ascii=False, indent=1))

# self-check: monotone, in-bounds, pulses inside their segment
assert all(segments[i]["end"] >= segments[i]["start"] for i in range(len(segments)))
assert all(segments[i + 1]["start"] == segments[i]["end"] for i in range(len(segments) - 1))
assert all(s["start"] <= p <= s["end"] + 0.01 for s in segments for p in s["junction_pulses"])
print(f"OK timeline: video {video_len:.1f}s, {len(segments)} segments -> {out/'timeline.json'}")
for s in segments:
    print(f"  {s['start']:6.2f}-{s['end']:6.2f}  {s.get('catname') or '----':4s} "
          f"hue{s['hue']:+4d} heat={s['heat']:.2f} pulses={len(s['junction_pulses'])}  "
          f"{s['attn_label'] or s['label']}")
