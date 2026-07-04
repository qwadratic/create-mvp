# Engine internals: the make features doing the work

The whole engine is one file, [`engine/build.mk`](../engine/build.mk) (~120 lines).
Everything below is stock GNU make — nothing patched or wrapped. Each section:
what the feature does here, why it earns its place. Excerpts are verbatim from
the engine unless labeled.

## `.DELETE_ON_ERROR` — a failed agent never counts as done

```make
.DELETE_ON_ERROR:  # failed agent ≠ done artifact
```

Agents write output *while* running. Crash, timeout, or gate rejection leaves
a garbage target on disk. Without the directive, make sees the file, calls it
up to date, builds downstream on a half-written plan. With it, a failed
recipe's target is deleted; the next run rebuilds it.

This makes every recipe line a *gate*. The plan rule:

```make
$(B)/plan.json: $(GOAL) $(B)/effort.json
	$(AGENT) plan $< > $@
	jq -e --argjson maxf $(MAXFANOUT) 'def okid: type=="string" and test("^[a-z0-9][a-z0-9-]{0,63}$$"); (.components | length > 0 and length <= $$maxf) and all(.components[]; (.id|okid) and all(.deps[]?; okid) and ((.kind // "leaf") == "leaf" or (.sub_goal | type=="string" and length > 0)))' $@ > /dev/null   # gate: bounded fanout; composite ⇒ sub_goal; id/dep charset — ids splice into make targets + shell recipe lines via the jq template (LLM output = trust boundary)
```

A failing `jq -e` fails the recipe, deletes `plan.json`, stops the pipeline —
an invalid decomposition cannot leak downstream. The same pattern gates the
effort knob row (schema check), every component (`check.sh`), and the final
review (`grep -q 'VERDICT: PASS'`).

`okid` is a security gate, not a style check: component ids splice verbatim
into `components.mk` — make target names, shell recipe arguments, `src/<id>`
path components. An LLM-authored id like `x; rm -rf .` or `../escape` would
inject recipe text or walk out of the source tree, so ids and dep references
are allowlisted to `[a-z0-9-]` before any generation (`engine/subtree`
re-checks the same regex as defense in depth).

## `-include` + generated `components.mk` — the agent-shaped DAG

Make's little-known superpower: an out-of-date included makefile with a
rebuild rule gets rebuilt, and make **restarts itself** with the new content.
So the dependency graph itself comes from the planning agent — shown reduced
to its leaf-only core (composite fork in the same template; see the recursive
`$(MAKE)` section):

```make
-include $(B)/components.mk
$(B)/components.mk: $(B)/plan.json
	jq -r '.components[] | "$(B)/\(.id).done: $(B)/plan.json \(.deps | map("$(B)/\(.).done") | join(" "))\n\t$$(AGENT) build \(.id)\n\tbash $(SRC)/\(.id)/check.sh\n\ttouch $$@\nCOMPONENTS += $(B)/\(.id).done\n"' $< > $@
```

Fresh run: make parses, sees `components.mk` missing (`-` suppresses the
error), finds its rule, which pulls in `plan.json`, which pulls in
`effort.json` (deterministic jq from the `TIER` knob) and fires the planner
agent. jq turns
`plan.json` into makefile rules; make restarts with a DAG shaped exactly like
the agent's decomposition. No templating engine, no codegen framework:
`jq -r` printing text.

A generated rule (from a real demo run):

```make
build/backend-server.done: build/plan.json build/db-seed.done
	$(AGENT) build backend-server
	bash src/backend-server/check.sh
	touch $@
```

## Sentinel `.done` targets

A component agent produces a *directory* (`src/<id>/`), not a single artifact
make can timestamp. So each component gets a sentinel: `touch $@` creates
`build/<id>.done` only after the build agent finished **and** `check.sh`
passed. The sentinel's mtime is the component's "last known good"; downstream
depends on it, not on the source directory.

With `.DELETE_ON_ERROR`, the invariant: *a `.done` file exists if and only if
that component was built and verified.* This also makes progress reporting
trivial (census below).

## Order-only prerequisites — `| $(B)`

```make
$(B)/effort.json: $(GOAL) | $(B)
	jq -cn --arg t "$(TIER)" --arg max "$(MAXTIER)" '…knob table…' > $@
```

After `|` is an *order-only* prerequisite: `build/` must exist before the
recipe runs; timestamp ignored. Directory mtime changes with every file
created inside, so a normal prerequisite on `$(B)` marks every artifact
perpetually stale. Order-only: "make sure it's there, then never look at it
again."

## `make -jN` — a free agent scheduler

No scheduler code in create-mvp. Parallel agent orchestration is
`make -j4 all`: make walks the generated DAG, launches every
dependency-satisfied component as a concurrent agent process, holds back the
rest. Dependency ordering, fan-out, fan-in on the review gate, load limiting
(`-j N`), keep-going (`-k`) — inherited from forty years of build-system
engineering, not reimplemented.

## Automatic variables in generated rules

The jq template above writes `$$(AGENT)` and `$$@`, not `$(AGENT)` and `$@`.
The doubled `$$` escapes expansion *in the generator recipe*: the literal
`$(AGENT)` / `$@` land in `components.mk`, expanding when *that* file's rules
run. One character decides which of two make passes a variable belongs to.
In the engine itself the usual automatic variables do the plumbing: `$<` (first prerequisite — the goal file, the
plan), `$@` (the artifact being produced), `$*` (the stem in pattern rules).

## Progress is a filesystem census

Every pipeline stage is a file, so "how far along are we?" needs no state,
database, or daemon — check which files exist:

```make
ARTIFACTS = $(B)/effort.json $(B)/plan.json $(COMPONENTS) $(B)/report.md
progress:
	@done=0; total=0; \
	for f in $(ARTIFACTS); do \
	  total=$$((total+1)); \
	  if [ -f $$f ]; then done=$$((done+1)); printf ' \033[32m✓\033[0m %s\n' $$f; \
	  ...
```

`make progress` prints a checklist with a bar, always truthful: the files
*are* the state. The same property drives `make graph`, which parses the rule
files back into a mermaid diagram — the DAG you see is the DAG that runs.

## Resume semantics

Make's founding feature, free for agents: a target newer than its
prerequisites is skipped. Kill a run anywhere — Ctrl-C, laptop lid, crashed
agent — rerun `make`; only missing or stale work reruns. `.done` components
never rebuild; the failed one (deleted by `.DELETE_ON_ERROR`) restarts; the
rest proceeds. No "resume mode" — resume is the default. Starting over is
deliberate: `make clean` (`rm -rf build/ src/`).

## Recursive `+$(MAKE)` — composite components as nested projects

One planning call cannot foresee a big build. So a plan component may declare
`"kind": "composite"` with a `sub_goal`; instead of one giant agent session it
becomes a *complete nested project* at `src/<id>/` — own `goal.md`, own
three-line Makefile including the same `build.mk`, own plan → build →
review pipeline (budget inherited from the parent). Full design in [`rfc-nested.md`](rfc-nested.md); this
section covers the make machinery. A generated composite rule:

```make
build/api-layer.done: build/plan.json build/schema.done
	$(ENGINE)subtree api-layer
	+$(MAKE) -C src/api-layer GOAL=goal.md B=build SRC=src AGENTMAKE_DEPTH=1 MAXTIER=$$(jq -r .tier build/effort.json) all
	bash src/api-layer/check.sh
	touch $@
```

Every token on the `+$(MAKE)` line is load-bearing.

**The `+` prefix and the jobserver.** GNU make coordinates parallelism across
recursive invocations through a *jobserver*: a shared token pipe, file
descriptors riding `MAKEFLAGS`. The `+` marks the line as recursive make,
granting the child those descriptors (and running the line even under
`-n`/`-q` dry runs). Consequence: one `-j4` at the top budgets agent
parallelism for the *entire* nested run — no `-jN` at any nested level; a
parent releases its job token while its sub-make runs, so composite recipes
don't pin slots waiting on subtrees. `$(MAKE)` over literal `make` is the
same contract: it activates `MAKEFLAGS` plumbing and jobserver inheritance.

**Variables ride the command line, not the environment.** The depth counter
(`AGENTMAKE_DEPTH=1`) and effort ceiling (`MAXTIER=…`) are command-line
assignments because of make's variable-origin precedence. The child's
`AGENTMAKE_DEPTH ?= 0` would silently skip an environment value — `?=`
assigns only when undefined, and env counts as defined — so an exported depth
would *never increment*, leaving the depth bound dead code. Command-line
origin is strongest: it survives the child's `?=` and beats assignments
propagated through `MAKEFLAGS` from above. The same line pins
`GOAL=goal.md B=build SRC=src` so a parent with non-default paths cannot leak
them into children.

**`.DELETE_ON_ERROR` is per-instance, and that's the point.** Scope is one
make instance; recursion gives each subtree its own. A grandchild's gate
fails: the grandchild's instance deletes the grandchild's artifacts; the
child's `all` fails; that non-zero exit fails the parent's composite recipe
*before* `touch $@` — the parent sentinel is never created, nothing partial
to clean up. Failure bubbles up N levels with zero new mechanism, just exit
codes crossing make boundaries, `make[2]: *** [target] Error 1` breadcrumbs
naming each level. The sentinel invariant survives recursion: the delegating
`check.sh` in each subtree re-checks the child review's `VERDICT: PASS`, so a
parent `.done` exists if and only if the component was built *and* verified —
it just means "the whole subtree" now.

**Three deterministic bounds, none of them prompt trust.** No bound depends
on an LLM obeying instructions. `AGENTMAKE_MAXDEPTH` (default 3): at the cap
the jq template emits the leaf branch regardless of the planner — `desc`
stays mandatory as the buildable fallback, so a composite-grade component
still builds as one unit. `MAXTIER`: the child's `TIER` clamped to the
parent's in the build.mk knob rule — the *whole* knob row, not just the tier
string (a clamped tier keeping prd fanout and a large model would defeat the
point) — effort monotone non-increasing down the tree. `MAXFANOUT` (default
8): the plan gate rejects wider decompositions per level; tree bounded at
MAXFANOUT^MAXDEPTH leaves. The planner controls tree *shape* within these
bounds, never exceeds them.

**A `cmp` guard preserves resume across the boundary.** The `subtree` helper
rewrites a child's `goal.md` only when the planned `sub_goal` text changed,
comparing with `cmp` first. An unchanged goal keeps its mtime, so a
re-invoked parent descends and finds everything up to date — the child
resumes at its first missing artifact instead of replanning. Timestamp
semantics, the same trick `board.mk` uses, stretched across a process
boundary.

## Nested census — the tools recurse with the tree

Progress, graph, and wfcheck follow the recursion, each with the smallest
mechanism that stays truthful.

`make progress` prints the parent's bar, then runs
`$(MAKE) -s -C src/<id> progress` per composite, indenting the child's
output. Deliberately *no* merged whole-tree percentage: one number averaging
levels of wildly unequal cost would lie; each level reports its own bar. A
composite planned but not yet scaffolded prints `(subtree, not scaffolded)` —
the honest rendering of lazy planning; an unplanned subtree has no leaf count
yet to report against.

`make graph` wraps each subtree's diagram in a mermaid `subgraph` block and
prefixes child node ids with the component id (`build/plan.json` →
`api-layer/build/plan.json`) — without namespacing, mermaid merges
identically-named nodes across subtrees. A final edge from the child's
`report.md` to the parent's `.done` sentinel draws the verdict bubble into
the picture.

`wfcheck` re-invokes itself on each composite's directory — a subtree is
indistinguishable from a top-level project, so the same script applies
unchanged. Each subtree contributes exactly *one* check (`subtree:<id>`) to
its parent's score, not its flattened checks, so a wide subtree cannot dilute
a small parent; a parent passes only if every subtree passes, recursively.
Drill-down preserved: every level writes its own `build/wfscore.json`, and
the parent's carries a `subtrees` summary map pointing at them. Flat projects
hit none of these code paths — output stays byte-identical.
