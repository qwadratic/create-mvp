#!/usr/bin/env python3
"""session-trace.jsonl -> out/session.attn.json  (ATTN-SPEC session mode, attn-proxy/1).

Everything emitted is an INTERPRETIVE PROXY -- weights derive from forth
grammar structure, token categories, and session recency. NOT model attention.
stdlib only.
"""
import json, math, re, sys, datetime, pathlib

DISCLAIMER = "interpretive proxy — not model internals"
HERE = pathlib.Path(__file__).parent
TRACE = HERE / "session-trace.jsonl"
OUT = HERE / "out" / "session.attn.json"

# --- dialect tables (ATTN-SPEC §1 + forth-tool words) -----------------------
CATS = {
    **{w: "def" for w in (":", ";", "variable", "constant")},
    **{w: "ctl" for w in ("if", "else", "then", "begin", "until", "do", "loop", "i")},
    **{w: "stk" for w in ("dup", "drop", "swap", "over", "rot")},
    **{w: "prim" for w in ("+", "-", "*", "/", "mod", "negate", "=", "<", ">",
                           "@", "!", ".", "emit", "cr", "token", "h.", "h=", "h>n",
                           '."', 's"',
                           # forth-tool coding words (real builtins of this VM)
                           "load", "fread", "fwrite", "words", "see")},
}
ARITY = {"dup": (1, 2), "drop": (1, 0), "swap": (2, 2), "over": (2, 3), "rot": (3, 3),
         "+": (2, 1), "-": (2, 1), "*": (2, 1), "/": (2, 1), "mod": (2, 1),
         "negate": (1, 1), "=": (2, 1), "<": (2, 1), ">": (2, 1),
         "@": (1, 1), "!": (2, 0), ".": (1, 0), "emit": (1, 0), "cr": (0, 0),
         "token": (0, 1), "h.": (1, 0), "h=": (2, 1), "h>n": (1, 2), "i": (0, 1),
         "load": (1, 0), "fread": (1, 1), "fwrite": (2, 0)}
MAX_ACT = 6
NUM = re.compile(r"^[+-]?\d+$")
JUNCTION = {"if": 0.8, "else": 0.8, "until": 0.8, "loop": 0.8,
            "begin": 0.4, "do": 0.4, "then": 0.4}
DECISION = {"if", "else", "until", "loop"}

# --- tokenizer ---------------------------------------------------------------
def looks_like_forth(payload):
    return "\n" in payload and (": " in payload or "variable " in payload)

def tokenize(code, line0=0):
    """-> [(text, line, col, is_payload)] ; s\" payloads that look like forth
    are tokenized nested (they ARE the program being written)."""
    toks = []
    line, col, i = line0, 1, 0
    while i < len(code):
        ch = code[i]
        if ch == "\n":
            line += 1; col = 1; i += 1; continue
        if ch in " \t":
            col += 1; i += 1; continue
        # comment \ to EOL
        if ch == "\\" and (i + 1 >= len(code) or code[i + 1] in " \n"):
            j = code.find("\n", i)
            j = len(code) if j < 0 else j
            toks.append((code[i:j], line, col, False))
            col += j - i; i = j; continue
        # word
        j = i
        while j < len(code) and code[j] not in " \t\n":
            j += 1
        word = code[i:j]
        wl = word.lower()
        toks.append((word, line, col, False))
        col += j - i; i = j
        if wl in ('s"', '."'):  # string payload to next "
            if i < len(code) and code[i] == " ":
                i += 1; col += 1
            k = code.find('"', i)
            k = len(code) if k < 0 else k
            payload = code[i:k]
            if wl == 's"' and looks_like_forth(payload):
                toks.extend((t, l, c, True) for t, l, c, _ in tokenize(payload, line))
            else:
                toks.append((payload, line, col, "lit"))  # string payload = lit
            line += payload.count("\n")
            col = 1 if "\n" in payload else col + len(payload)
            i = k + 1 if k < len(code) else k
            if i <= len(code):
                toks.append(('"', line, col, False))
    return toks

def cat_of(t, defs, prev, hint=None):
    tl = t.lower()
    if hint == "lit":
        return "lit"                       # s"/."  string payload
    if prev in (":", "variable", "constant"):
        return "def"                       # name token at def site
    if tl.startswith("\\"):
        return "com"
    if tl in CATS:
        return CATS[tl]
    if NUM.match(tl):
        return "lit"
    if tl in defs:
        return "usr"
    return "usr"                           # unknown -> usr w=0 bug beacon

# --- load trace --------------------------------------------------------------
def iso_s(ts):
    return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()

calls = []
with open(TRACE) as f:
    for line in f:
        e = json.loads(line)
        if e.get("type") != "message":
            continue
        m = e["message"]
        if m.get("role") != "assistant":
            continue
        for p in m.get("content", []):
            if p.get("type") == "toolCall":
                calls.append({"ts": e["timestamp"], "t": iso_s(e["timestamp"]),
                              "code": p["arguments"]["code"]})
assert len(calls) == 11, f"expected 11 forth calls, got {len(calls)}"

# --- pass 1: dictionary across the whole session (persistent VM) -------------
defs, defline, refcount = set(), {}, {}
gline = 0
per_call_tokens = []
for c in calls:
    toks = tokenize(c["code"], line0=gline)
    per_call_tokens.append(toks)
    prev = None
    for text, line, col, nested in toks:
        tl = text.lower()
        if nested == "lit":
            prev = tl; continue
        if prev in (":", "variable", "constant") and not tl.startswith("\\"):
            defs.add(tl); defline.setdefault(tl, line); refcount.setdefault(tl, 0)
        elif tl in defs:
            refcount[tl] += 1
        prev = tl if not tl.startswith("\\") else prev
    gline = max((l for _, l, _, _ in toks), default=gline) + 1
maxref = max(refcount.values() or [1])
total_lines = gline

# --- pass 2: weights, edges, frames ------------------------------------------
tokens, edges, frames = [], [], []
tid = 0
for fi, (c, toks) in enumerate(zip(calls, per_call_tokens)):
    depth = 0
    prev = None
    stack = []            # abstract stack of producer token ids (§2.2)
    jstack = []           # junction pair stack (§2.3)
    first_tid = tid
    catw = {}             # per-frame cat -> sum(w)
    tscore = {"defuse": 0.0, "stack": 0.0, "junction": 0.0}
    njunc = 0
    name_tid = {}         # word -> def-site token id (session-global)
    for text, line, col, nested in toks:
        tl = text.lower()
        c_ = cat_of(text, defs, prev, hint=nested if nested == "lit" else None)
        if c_ == "com":
            w = 0.05
        else:
            w_ref = w_stack = w_edge = w_j = 0.0
            is_def_name = prev in (":", "variable", "constant")
            if (is_def_name or tl in defs) and tl in refcount:
                w_ref = math.log2(1 + refcount[tl]) / math.log2(1 + maxref)
            if tl in ARITY:
                cns, prd = ARITY[tl]
                w_stack = (cns + prd) / MAX_ACT
            if c_ == "usr" and tl in defline and not is_def_name:
                d = abs(line - defline[tl])
                w_edge = min(1.0, math.log(1 + d) / math.log(1 + total_lines))
            if tl in JUNCTION and not is_def_name:
                w_j = JUNCTION[tl] * min(1.5, 1 + 0.15 * depth)
                njunc += tl in DECISION
            base = {"lit": 0.15, "def": 0.30}.get(c_, 0.0)
            w = min(1.0, (base + w_ref + w_stack + w_edge + w_j) / 1.6)
            if tl in defs and tl not in defline:  # unknown-word beacon (never here)
                w = 0.0
            tscore["defuse"] += w_ref + w_edge
            tscore["stack"] += w_stack
            tscore["junction"] += w_j
        junc = ("decision" if tl in DECISION else
                "anchor" if tl in JUNCTION else None) if c_ == "ctl" else None
        tokens.append({"i": tid, "line": line, "col": col,
                       "text": text if len(text) <= 48 else text[:45] + "…",
                       "cat": c_, "w": round(w, 3), "depth": depth,
                       "junction": junc, "frame": fi})
        catw[c_] = catw.get(c_, 0.0) + w
        # edges: def-use
        is_def_name = prev in (":", "variable", "constant")
        if is_def_name:
            name_tid[tl] = tid
        elif c_ == "usr" and tl in name_tid:
            edges.append({"type": "defuse", "from": name_tid[tl], "to": tid,
                          "w": round(min(1.0, math.log(1 + abs(line - defline[tl]))
                                         / math.log(1 + total_lines)), 3)})
        # edges: stack coupling (known arities only; usr = barrier)
        if tl in ARITY and not is_def_name:
            cns, prd = ARITY[tl]
            for _ in range(cns):
                if stack:
                    edges.append({"type": "stack", "from": stack.pop(), "to": tid, "w": 0.4})
            stack.extend([tid] * prd)
        elif NUM.match(tl):
            stack.append(tid)
        elif c_ == "usr":
            stack.clear()
        # edges: junction pairs
        if tl in ("if", "begin", "do") and not is_def_name:
            jstack.append(tid); depth += 1
        elif tl in ("else",) and jstack:
            edges.append({"type": "pair", "from": jstack[-1], "to": tid, "w": 0.6})
            jstack[-1] = tid
        elif tl in ("then", "until", "loop") and not is_def_name:
            if jstack:
                edges.append({"type": "pair", "from": jstack.pop(), "to": tid, "w": 0.6})
            depth = max(0, depth - 1)
        prev = tl
        tid += 1
    dom = max(catw, key=catw.get) if catw else "prim"
    attn_type = max(tscore, key=tscore.get)
    ATTN_LABEL = {"defuse": "def-use edges · long-range",
                  "stack": "stack-effect coupling · local",
                  "junction": "control junctions · salience",
                  "dict": "dictionary scan · introspection"}
    if max(tscore.values()) < 0.05:
        attn_type = "dict"
    lines_touched = sorted({t["line"] for t in tokens[first_tid:tid]})
    frames.append({"idx": fi, "tool": "forth", "ts": c["ts"],
                   "file": "forth-tool VM (persistent)",
                   "touched_lines": [lines_touched[0], lines_touched[-1]] if lines_touched else [],
                   "recency": [[fj, round(math.exp(-(fi - fj) / 6), 3)] for fj in range(max(0, fi - 3), fi + 1)],
                   # extra fields (consumers ignore): drive video grade + live replay
                   "tokens": [first_tid, tid],
                   "dominant_cat": dom,
                   "attn_type": attn_type,
                   "attn_label": ATTN_LABEL[attn_type],
                   "decision_junctions": njunc,
                   "cat_weights": {k: round(v, 2) for k, v in sorted(catw.items(), key=lambda x: -x[1])}})

sidecar = {
    "version": 1,
    "heuristic": "attn-proxy/1",
    "disclaimer": DISCLAIMER,
    "source": "demoscene/session-trace.jsonl",
    "mode": "session",
    "generated": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "params": {"tau": 6, "junction_bonus": [0.8, 0.4], "norm": 1.6},
    "cats": ["def", "ctl", "stk", "lit", "com", "usr", "prim"],
    "tokens": tokens,
    "edges": edges,
    "frames": frames,
}
OUT.parent.mkdir(exist_ok=True)
OUT.write_text(json.dumps(sidecar, ensure_ascii=False, indent=1))

# --- self-check (spec §3 invariants on real session data) --------------------
byw = {}
for t in tokens:
    byw.setdefault(t["text"].lower(), []).append(t["w"])
assert all(t["w"] <= 1.0 for t in tokens), "clamped"
assert sidecar["disclaimer"] == DISCLAIMER
assert max(byw.get("band", [0])) > 0.3, "hot user word salient"
assert any(e["type"] == "defuse" for e in edges) and any(e["type"] == "pair" for e in edges)
print(f"OK sidecar: {len(tokens)} tokens, {len(edges)} edges, {len(frames)} frames -> {OUT}")
for fr in frames:
    print(f"  frame {fr['idx']:2d} {fr['ts'][11:19]} cat={fr['dominant_cat']:4s} "
          f"junc={fr['decision_junctions']:2d} {fr['attn_label']}")
