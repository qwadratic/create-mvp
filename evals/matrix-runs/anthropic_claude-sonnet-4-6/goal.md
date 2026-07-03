# Goal
`wordfreq` — word-frequency CLI.

- `wordfreq.py`: reads text from stdin, prints a JSON array of the top-N most
  frequent words: `[{"word": "...", "count": N}, ...]`, sorted by count desc,
  then word asc for ties. N from `--top N` (default 5). Words = lowercased,
  split on any non-letter character.
- Deterministic: same input -> byte-identical output (jq-diffable).
- Include a golden test: fixed input file + expected JSON output file, compared
  via jq in the check.
- python3 stdlib only; no pip, no docker, no network.
