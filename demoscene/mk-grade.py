#!/usr/bin/env python3
"""out/raw.mp4 + out/timeline.json -> out/final-v{1,2}.mp4  (graded demoscene cut).

Grade is keyed to the ATTN sidecar timeline (interpretive proxy — not model
internals; the honesty label is burned into every frame):
  - hue rotation per segment   = dominant token CATEGORY
  - saturation per segment     = proxy heat (total weight)
  - junction pulses (v2)       = chromatic-aberration + brightness spikes
  - drawtext labels            = category + attention type per segment
Usage: python3 mk-grade.py v1|v2
stdlib only (drives ffmpeg).
"""
import json, pathlib, subprocess, sys

HERE = pathlib.Path(__file__).parent
OUT = HERE / "out"
VER = sys.argv[1] if len(sys.argv) > 1 else "v2"
FONT = "/System/Library/Fonts/Menlo.ttc"
DISCLAIMER = "interpretive proxy — not model internals"

tl = json.loads((OUT / "timeline.json").read_text())
assert tl["disclaimer"] == DISCLAIMER, "reject timeline: disclaimer missing/altered"
segs = tl["segments"]

# --- scanline pattern (once, not per frame) -----------------------------------
W, H = 1028, 726
pgm = bytearray(f"P5\n{W} {H}\n255\n".encode())
for y in range(H):
    pgm += bytes([190 if y % 3 == 2 else 255]) * W
(OUT / "scanlines.pgm").write_bytes(pgm)

# --- piecewise expressions from segments --------------------------------------
def piecewise(field, default):
    expr = str(default)
    for s in reversed(segs):
        expr = f"if(between(t,{s['start']},{s['end']}),{field(s)},{expr})"
    return expr

hue_expr = piecewise(lambda s: s["hue"], 0)
if VER == "v1":
    sat_expr = piecewise(lambda s: round(0.85 + 0.45 * s["heat"], 3), 1)
else:  # v2: gentle breathing on top of heat
    sat_expr = f"({piecewise(lambda s: round(0.85 + 0.45 * s['heat'], 3), 1)})*(1+0.05*sin(2*PI*t/3))"

CATCOLOR = {"DEF": "0xff87ff", "CTL": "0xffaf00", "STK": "0x00ffff",
            "LIT": "0xeeeeee", "COM": "0x808080", "USR": "0x5fafff", "PRIM": "0x87d787"}

def dt(text, **kw):
    esc = text.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\\\\\'")
    args = ":".join(f"{k}={v}" for k, v in kw.items())
    return f"drawtext=fontfile={FONT}:text='{esc}':{args}"

labels = []
for s in segs:
    en = f"enable='between(t,{s['start']},{s['end']})'"
    if s["cat"] is None:
        labels.append(dt("forth-evolution · agent grows a compiler test via one forth tool",
                         fontsize=22, fontcolor="0x87d787", x=24, y=20,
                         box=1, boxcolor="black@0.45", boxborderw=10) + f":{en}")
        continue
    labels.append(dt(f"ATTN cat {s['catname']}", fontsize=22,
                     fontcolor=CATCOLOR[s["catname"]], x=24, y=20,
                     box=1, boxcolor="black@0.45", boxborderw=10) + f":{en}")
    labels.append(dt(s["attn_label"], fontsize=18, fontcolor="white@0.85",
                     x=24, y=52, box=1, boxcolor="black@0.45", boxborderw=8) + f":{en}")

# persistent honesty label — burned into pixels, every frame
labels.append(dt(f"attention grade = {DISCLAIMER}", fontsize=15,
                 fontcolor="white@0.60", x="w-tw-18", y="h-th-12",
                 box=1, boxcolor="black@0.35", boxborderw=6))

pulses = [(p, round(p + 0.35, 2)) for s in segs for p in s["junction_pulses"]]

if VER == "v2":
    # junction pulse flash label
    for s in segs:
        for p in s["junction_pulses"]:
            labels.append(dt(f"◆ control junction ({s['junctions']}x)", fontsize=20,
                             fontcolor="0xffaf00", x="(w-tw)/2", y=90)
                          + f":enable='between(t,{p},{p + 0.35})'")
    # end card
    end0 = segs[-1]["end"] - 5
    labels.append(dt("golden test landed first try · wfcheck 32/32 · selfhost ACHIEVED",
                     fontsize=20, fontcolor="0x87d787", x="(w-tw)/2", y="h-64",
                     box=1, boxcolor="black@0.5", boxborderw=10)
                  + f":enable='gte(t,{end0})'")

label_chain = ",".join(labels)

if VER == "v1":
    # hue is YUV-only: it must come BEFORE format=gbrp, or negotiation flips the
    # whole chain back to YUV and the screen/multiply blends hit chroma planes
    # (magenta wash). shortest=1 on the scanline blend: the -loop 1 image never
    # EOFs and framesync repeatlast would render forever (mux -shortest can't stop it).
    graph = f"""
[0:v]hue=h='{hue_expr}':s='{sat_expr}',format=gbrp[tint];
[tint]split[base][fg];
[fg]gblur=sigma=9[gl];
[base][gl]blend=all_mode=screen:all_opacity=0.50[glow];
[glow]rgbashift=rh=-1:bh=1[ab];
[ab][1:v]blend=all_mode=multiply:all_opacity=0.30:shortest=1[scan];
[scan]vignette=PI/4.6[vig];
[vig]curves=r='0/0 0.5/0.46 1/0.96':g='0/0.02 0.5/0.55 1/1':b='0/0.01 0.5/0.48 1/0.94'[graded];
[graded]{label_chain},format=yuv420p[out]
"""
else:
    pulse_enable = "+".join(f"between(t,{a},{b})" for a, b in pulses) or "0"
    graph = f"""
[0:v]hue=h='{hue_expr}':s='{sat_expr}',format=gbrp[tint];
[tint]split[base][fg];
[fg]gblur=sigma=8[gl];
[base][gl]blend=all_mode=screen:all_opacity=0.45[glow];
[glow]split[calm0][hot0];
[calm0]rgbashift=rh=-1:bh=1[calm];
[hot0]rgbashift=rh=-6:bh=6:gv=2,eq=brightness=0.07:saturation=1.35[hot];
[calm][hot]overlay=enable='{pulse_enable}'[ab];
[ab][1:v]blend=all_mode=multiply:all_opacity=0.28:shortest=1[scan];
[scan]vignette=PI/4.8[vig];
[vig]curves=r='0/0 0.5/0.47 1/0.97':g='0/0.02 0.5/0.56 1/1':b='0/0.01 0.5/0.50 1/0.95'[graded];
[graded]{label_chain},format=yuv420p[out]
"""

script = OUT / f"grade-{VER}.filter"
script.write_text(graph.strip())
dst = OUT / f"final-{VER}.mp4"
cmd = ["ffmpeg", "-y", "-v", "error", "-stats",
       "-i", str(OUT / "raw.mp4"),
       "-loop", "1", "-i", str(OUT / "scanlines.pgm"),
       "-filter_complex_script", str(script),
       "-map", "[out]", "-r", str(tl["fps"]),
       "-c:v", "libx264", "-preset", "medium", "-crf", "20",
       "-shortest", str(dst)]
if "--probe" in sys.argv:  # 10s slice for iteration
    cmd[5:5] = ["-t", "12"]
    dst_probe = OUT / f"probe-{VER}.mp4"
    cmd[-1] = str(dst_probe)
    dst = dst_probe
print(" ".join(cmd))
subprocess.run(cmd, check=True)
print(f"OK {dst}")
