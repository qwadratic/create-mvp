# Build System Review: wordfreq

## Goal Verification
CLI tool reading stdin, outputting top-N word frequencies as compact JSON array `[{"word": "...", "count": N}, ...]`, sorted by count descending then word ascending. Default N=5. Words: lowercased, split on [^a-z]. Deterministic. Golden test included. Python3 stdlib only.

## Per-Component Verdicts

### word-counter/counter.py ✓ PASS
**Role:** Core frequency engine. Reads stdin, splits on non-letters, lowercases, counts.

**Tests:** 5/5 passing
- Basic word counting (case folding, deduplication)
- Non-letter splitting (punctuation, underscores, numbers)
- Empty input handling
- Only-non-letters edge case
- Numbers as delimiters

**Code Quality:** Correct regex `[^a-z]+`, proper filtering of empty strings, deterministic dict output with `sort_keys=True`.

### json-formatter/formatter.py ✓ PASS
**Role:** Sorts frequency dict by count (desc) then word (asc). Outputs compact JSON array.

**Tests:** 6/6 passing
- Sorting by count desc + word asc tie-breaking
- Compact JSON output (no spaces)
- Deterministic (same input → same output)
- Empty dict handling
- Single entry
- Alphabetical ordering for ties

**Code Quality:** Correct sort key `(-count, word)` for stable ordering. Compact separators `(',', ':')`. `ensure_ascii=True` for determinism.

### cli-interface/wordfreq.py ✓ PASS
**Role:** CLI entry point. Parses `--top N` (default 5), pipes stdin through counter + formatter, slices top-N, outputs compact JSON.

**Tests:** 10/10 passing
- Default `--top 5` (implicit)
- Explicit `--top N`
- Slicing when N > results (returns all)
- `--top 0` returns empty array
- Determinism
- Sorting tie-breaking (count desc, word asc)
- Compact JSON output
- Empty input
- Non-letter splitting
- Case insensitivity

**Code Quality:** Subprocess piping correct. Path resolution via `os.path` relative to script location. Error handling for missing scripts or subprocess failures.

### golden-test/check.sh ✓ PASS
**Role:** Fixed input/output determinism test. Compares canonical JSON via `jq -S`.

**Verification:**
- Input file exists: `input.txt` (7-line text)
- Golden file exists: `golden.json` (pretty-printed, top-5 results)
- CLI integration: input → wordfreq.py → jq -S → byte-identical to golden.json
- Test result: PASS (byte-identical match)

**Code Quality:** Proper file existence checks. Uses `jq -S` for canonical (sorted-key) comparison, ensuring true byte-identical verification.

## Integration Verdict

**End-to-end test:** Input text → counter → formatter → CLI slicing → compact JSON
```
cat src/golden-test/input.txt | python3 src/cli-interface/wordfreq.py --top 5
→ [{"word":"the","count":11},{"word":"dog","count":5},{"word":"fox","count":4},{"word":"lazy","count":3},{"word":"quick","count":3}]
```

**Requirements met:**
- ✓ Stdin reading
- ✓ Word frequency counting (lowercased, split on [^a-z])
- ✓ JSON array output format
- ✓ Sorting: count desc, word asc for ties
- ✓ --top N parameter (default 5)
- ✓ Compact deterministic JSON (no spaces, `ensure_ascii=True`)
- ✓ Golden test with jq-diffable output
- ✓ Python3 stdlib only (subprocess, json, re, sys, argparse, os)
- ✓ All component tests passing
- ✓ All integration paths tested

**Concerns:** None. All tests pass. System architecture is modular with clear separation of concerns.

VERDICT: PASS
