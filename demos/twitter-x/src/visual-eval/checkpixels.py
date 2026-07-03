#!/usr/bin/env python3
"""Structural pixel assertions for the twitter-x home screenshot.

usage: checkpixels.py shot.png
Decodes via ffmpeg (already required by evalshot). Asserts:
  1. dark background overall
  2. left nav rail present (bright text + blue Post button, x < 300)
  3. compose box present (blue Post button inside center column, upper area)
  4. >= 3 tweet cards (>= 4 avatar blobs in the center-column avatar strip:
     compose avatar + 3 tweets)
Exit 0 pass, 1 fail, 2 usage/env error.
"""
import struct
import subprocess
import sys


def png_dims(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit("checkpixels: not a PNG: %s" % path)
    w, h = struct.unpack(">II", head[16:24])
    return w, h


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: checkpixels.py shot.png")
    path = sys.argv[1]
    w, h = png_dims(path)
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo",
         "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True).stdout
    if len(raw) != w * h * 3:
        sys.exit("checkpixels: decode size mismatch")

    def px(x, y):
        i = (y * w + x) * 3
        return raw[i], raw[i + 1], raw[i + 2]

    def is_blue(r, g, b):  # #1d9bf0 full or ~50%-dimmed (disabled compose btn)
        return b > 90 and b > r + 40 and g > r and abs(b - g) < 110

    fails = []

    # layout geometry at 1280 wide: 1210px app centered -> offset 35
    off = max(0, (w - 1210) // 2)
    rail_x1 = off + 260          # nav rail right edge
    col_x0, col_x1 = rail_x1, rail_x1 + 600  # center column

    # 1. dark bg: mean luminance over a coarse grid
    tot = n = 0
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            r, g, b = px(x, y)
            tot += (r + g + b) // 3
            n += 1
    mean = tot / n
    if mean >= 48:
        fails.append("bg not dark (mean lum %.1f >= 48)" % mean)

    # 2. nav rail: bright text pixels and blue Post button in x < rail_x1
    bright = blue_rail = 0
    for y in range(0, h, 2):
        for x in range(0, rail_x1, 2):
            r, g, b = px(x, y)
            if r > 180 and g > 180 and b > 180:
                bright += 1
            if is_blue(r, g, b):
                blue_rail += 1
    if bright < 100:
        fails.append("nav rail: too few bright pixels (%d)" % bright)
    if blue_rail < 100:
        fails.append("nav rail: no blue Post button (%d blue px)" % blue_rail)

    # 3. compose box: blue Post button in center column, y < 320
    blue_compose = sum(
        1 for y in range(60, min(320, h), 2)
        for x in range(col_x0, min(col_x1, w), 2)
        if is_blue(*px(x, y)))
    if blue_compose < 30:
        fails.append("compose: no blue Post button in center column "
                     "(%d blue px)" % blue_compose)

    # 4. avatar blobs: saturated rows in strip where avatars live
    ax0, ax1 = col_x0 + 8, col_x0 + 64
    blobs, in_blob = 0, False
    for y in range(h):
        sat = sum(1 for x in range(ax0, ax1, 2)
                  if max(p := px(x, y)) - min(p) > 50)
        if sat >= 6:
            if not in_blob:
                blobs += 1
                in_blob = True
        else:
            in_blob = False
    if blobs < 4:  # compose avatar + >=3 tweet card avatars
        fails.append("only %d avatar blobs, need >=4 (compose + 3 tweets)"
                     % blobs)

    if fails:
        for f in fails:
            print("checkpixels: FAIL " + f, file=sys.stderr)
        sys.exit(1)
    print("checkpixels: PASS dark bg, nav rail, compose, %d avatar blobs "
          "(>=3 tweet cards)" % blobs)


if __name__ == "__main__":
    main()
