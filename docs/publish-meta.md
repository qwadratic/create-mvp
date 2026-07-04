# gh repo metadata draft — qwadratic/agentmake

Apply once the repo exists (account `qwadratic`, precedent: pi-mouse-tui public):

```sh
gh repo edit qwadratic/agentmake \
  --description "Agents write the DAG. make runs the agents. A ~120-line Makefile engine: goal file → planning agent → parallel, resumable, gate-checked build swarm. No orchestrator, no framework." \
  --add-topic ai-agents \
  --add-topic agentic-workflow \
  --add-topic gnu-make \
  --add-topic makefile \
  --add-topic llm \
  --add-topic build-system \
  --add-topic orchestration \
  --add-topic code-generation \
  --add-topic jq \
  --add-topic claude \
  --add-topic developer-tools \
  --add-topic automation
```

Notes:

- Description is 191 chars (gh limit ~350). Mirrors the README's first line so
  search snippets and the repo card say the same thing.
- Topics: `ai-agents` + `agentic-workflow` are the discovery terms;
  `gnu-make`/`makefile` are the differentiators nobody else in the agent space
  has; `jq`/`claude` match the actual stack. 12 total (limit 20) — leave slack
  for post-launch terms (e.g. `cook` once the one-shot CLI ships, per
  [naming.md](naming.md) HYBRID posture).
- Homepage flag intentionally omitted — nothing to point at yet; add
  `--homepage` when a pages/demo site exists.
