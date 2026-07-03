# Engine internals: the make features doing the work

The whole engine is one file, [`engine/build.mk`](../engine/build.mk) (~120 lines).
Every feature below is stock GNU make — nothing is patched or wrapped. This doc
explains what each feature does here and why it earns its place. Excerpts are
verbatim from the engine unless labeled otherwise.

## `.DELETE_ON_ERROR` — a failed agent never counts as done

```make
.DELETE_ON_ERROR:  # failed agent ≠ done artifact
```

Agents write their output *while* running. If an agent crashes, times out, or
its gate rejects the result, the target file exists on disk but is garbage.
Without this directive, make would see the file, consider the target up to
date, and happily build everything downstream on top of a half-written plan.
With it, make deletes the target of any failed recipe, so the next run rebuilds
it from scratch.

This is what makes every recipe line a *gate*. Take the plan rule:

```make
$(B)/plan.json: $(GOAL) $(B)/effort.json
	$(AGENT) plan $< > $@
	jq -e --argjson maxf $(MAXFANOUT) 'def okid: type=="string" and test("^[a-z0-9][a-z0-9-]{0,63}$$"); (.components | length > 0 and length <= $$maxf) and all(.components[]; (.id|okid) and all(.deps[]?; okid) and ((.kind // "leaf") == "leaf" or (.sub_goal | type=="string" and length > 0)))' $@ > /dev/null   # gate: bounded fanout; composite ⇒ sub_goal; id/dep charset — ids splice into make targets + shell recipe lines via the jq template (LLM output = trust boundary)
```

If the `jq -e` check fails, the recipe fails, `plan.json` is deleted, and the
pipeline stops — an invalid decomposition cannot leak downstream. The same
pattern gates the effort classifier (schema check), every component
(`check.sh`), and the final review (`grep -q 'VERDICT: PASS'`).

The `okid` clause is a security gate, not a style check: component ids are
spliced verbatim into `components.mk` — they become make target names, shell
recipe arguments, and `src/<id>` path components. An LLM-authored id like
`x; rm -rf .` or `../escape` would otherwise inject recipe text or walk out
of the source tree, so ids and dep references are allowlisted to
`[a-z0-9-]` before any generation happens (`engine/subtree` re-checks the
same regex as defense in depth).

## `-include` + generated `components.mk` — the agent-shaped DAG

Make has a little-known superpower: if an included makefile is out of date and
there is a rule to rebuild it, make rebuilds it and **restarts itself** with
the new content. The engine uses this so the dependency graph itself comes
from the planning agent — shown here reduced to its leaf-only core (the
composite fork lives in the same template; see the recursive `$(MAKE)`
section below):

```make
-include $(B)/components.mk
$(B)/components.mk: $(B)/plan.json
	jq -r '.components[] | "$(B)/\(.id).done: $(B)/plan.json \(.deps | map("$(B)/\(.).done") | join(" "))\n\t$$(AGENT) build \(.id)\n\tbash $(SRC)/\(.id)/check.sh\n\ttouch $$@\nCOMPONENTS += $(B)/\(.id).done\n"' $< > $@
```

Sequence on a fresh run: make parses, sees `components.mk` missing (the `-`
suppresses the error), finds the rule to build it, which pulls in `plan.json`,
which pulls in `effort.json`, which runs the classifier and planner agents.
Then jq turns `plan.json` into makefile rules, and make restarts — now with a
DAG shaped exactly like the agent's decomposition. No templating engine, no
code generation framework: `jq -r` printing text.

A generated rule looks like this (from a real demo run):

```make
build/backend-server.done: build/plan.json build/db-seed.done
	$(AGENT) build backend-server
	bash src/backend-server/check.sh
	touch $@
```

## Sentinel `.done` targets

A component agent produces a *directory* of files (`src/<id>/`), not a single
artifact make can timestamp. So each component gets a sentinel: `touch $@`
creates `build/<id>.done` only after the build agent finished **and** its
`check.sh` passed. The sentinel's mtime is the component's "last known good"
time; downstream components depend on it, not on the source directory.

Combined with `.DELETE_ON_ERROR`, the invariant is: *a `.done` file exists if
and only if that component was built and verified.* This is also what makes
progress reporting trivial (see census below).

## Order-only prerequisites — `| $(B)`

```make
$(B)/effort.json: $(GOAL) | $(B)
	$(AGENT) classify $< > $@
```

The part after `|` is an *order-only* prerequisite: `build/` must exist before
the recipe runs, but its timestamp is ignored. That distinction matters for
directories — a directory's mtime changes every time any file inside it is
created, so a normal prerequisite on `$(B)` would make every artifact look
perpetually stale and rebuild the world on each run. Order-only says "make
sure it's there, then never look at it again."

## `make -jN` — a free agent scheduler

There is no scheduler code in agentmake. Parallel agent orchestration is
`make -j4 all`: make walks the generated DAG, launches every component whose
dependencies are satisfied as a concurrent agent process, and holds back the
ones that must wait. Dependency ordering, fan-out, fan-in on the review gate,
load limiting (`-j N`), and keep-going semantics (`-k`) are all inherited from
forty years of build-system engineering rather than reimplemented.

## Automatic variables in generated rules

Look closely at the jq template above: it writes `$$(AGENT)` and `$$@`, not
`$(AGENT)` and `$@`. The doubled `$$` escapes expansion *in the generator
recipe* so that the literal `$(AGENT)` / `$@` land in `components.mk` and get
expanded when *that* file's rules run. One character deciding which of two
make passes a variable belongs to. In the engine itself the usual automatic
variables do the plumbing: `$<` (first prerequisite — the goal file, the
plan), `$@` (the artifact being produced), `$*` (the stem in pattern rules).

## Progress is a filesystem census

Because every pipeline stage is a file, "how far along are we?" needs no
state, no database, no daemon — just check which files exist:

```make
ARTIFACTS = $(B)/effort.json $(B)/plan.json $(COMPONENTS) $(B)/report.md
progress:
	@done=0; total=0; \
	for f in $(ARTIFACTS); do \
	  total=$$((total+1)); \
	  if [ -f $$f ]; then done=$$((done+1)); printf ' \033[32m✓\033[0m %s\n' $$f; \
	  ...
```

`make progress` prints a checklist with a bar, and it is always truthful: the
files *are* the state. The same property drives `make graph`, which parses the
rule files back into a mermaid diagram — the DAG you see is the DAG that runs.

## Resume semantics

This is make's founding feature, and agents get it for free: a target whose
prerequisites are older than itself is skipped. Kill a run at any point —
Ctrl-C, laptop lid, crashed agent — and rerunning `make` re-executes only what
is missing or stale. Finished components (their `.done` sentinels intact) are
never rebuilt; the failed one (deleted by `.DELETE_ON_ERROR`) restarts; the
untouched remainder proceeds. There is no "resume mode" because resuming is
the default behavior of the tool. `make clean` (`rm -rf build/ src/`) is the
only way to start over, deliberately.

## Recursive `+$(MAKE)` — composite components as nested projects

One planning call cannot foresee a big build. So a plan component may declare
`"kind": "composite"` with a `sub_goal`, and instead of one giant agent
session it becomes a *complete nested project* at `src/<id>/` — its own
`goal.md`, its own three-line Makefile including the same `build.mk`, its own
classify → plan → build → review pipeline. The design is documented in full in
[`rfc-nested.md`](rfc-nested.md); this section covers the make machinery that
makes it work. A generated composite rule looks like this:

```make
build/api-layer.done: build/plan.json build/schema.done
	$(ENGINE)subtree api-layer
	+$(MAKE) -C src/api-layer GOAL=goal.md B=build SRC=src AGENTMAKE_DEPTH=1 MAXTIER=$$(jq -r .tier build/effort.json) all
	bash src/api-layer/check.sh
	touch $@
```

Every token on the `+$(MAKE)` line is load-bearing.

**The `+` prefix and the jobserver.** GNU make coordinates parallelism across
recursive invocations through a *jobserver*: a shared token pipe whose file
descriptors are handed down via `MAKEFLAGS`. The `+` marks the line as a
recursive make, which is what grants the child access to those descriptors
(and runs the line even under `-n`/`-q` dry runs). The consequence is that a
single `-j4` at the top of the tree budgets agent parallelism for the *entire*
nested run — no `-jN` appears at any nested level, and a parent releases its
own job token while its sub-make runs, so composite recipes don't pin slots
while waiting on their subtrees. Using the `$(MAKE)` variable rather than a
literal `make` is part of the same contract: it is how `MAKEFLAGS` plumbing
and jobserver inheritance are activated.

**Variables ride the command line, not the environment.** The depth counter
(`AGENTMAKE_DEPTH=1`) and effort ceiling (`MAXTIER=…`) are passed as
command-line assignments, and that choice is about make's variable-origin
precedence. The child's own `AGENTMAKE_DEPTH ?= 0` would be silently skipped
if the value arrived through the environment — `?=` only assigns when the
variable is undefined, and an environment variable counts as defined — so an
exported depth would *never increment* and the depth bound would be dead code.
Command-line origin is the strongest there is: it survives the child's `?=`,
and it also beats assignments propagated through `MAKEFLAGS` from levels
above. The same line pins `GOAL=goal.md B=build SRC=src` so a parent running
with non-default paths cannot leak them into its children.

**`.DELETE_ON_ERROR` is per-instance, and that's the point.** The directive's
scope is one make instance, and recursion gives each subtree its own. When a
grandchild's gate fails, the grandchild's instance deletes the grandchild's
artifacts; the child's `all` fails; that non-zero exit fails the parent's
composite recipe *before* `touch $@`, so the parent sentinel is simply never
created — there is nothing partial for the parent to clean up. Failure
bubbles up N levels with zero new mechanism, just exit codes crossing make
boundaries, and `make[2]: *** [target] Error 1` breadcrumbs naming each level
on the way. The sentinel invariant survives recursion intact: the delegating
`check.sh` scaffolded into each subtree re-checks the child review's
`VERDICT: PASS`, so a parent `.done` still exists if and only if the component
was built *and* verified — it just means "the whole subtree" now.

**Three deterministic bounds, none of them prompt trust.** The tree cannot
run away, and no bound depends on an LLM obeying instructions.
`AGENTMAKE_MAXDEPTH` (default 3): at the cap the jq template emits the leaf
branch regardless of what the planner said — `desc` stays mandatory as the
buildable fallback, so a composite-grade component still builds as one unit.
`MAXTIER`: the child's classify output is clamped to the parent's tier in
`engine/agent` — the *whole* knob row, not just the tier string (a clamped
tier keeping prd fanout and a large model would defeat the point) — so effort
is monotone non-increasing down the tree. `MAXFANOUT` (default 8): the plan
gate rejects wider decompositions per level, bounding the tree at
MAXFANOUT^MAXDEPTH leaves. The planner controls tree *shape* within these
bounds; it cannot exceed them.

**A `cmp` guard preserves resume across the boundary.** The `subtree` helper
rewrites a child's `goal.md` only when the planned `sub_goal` text actually
changed, comparing with `cmp` before moving the new file into place. An
unchanged goal keeps its old mtime, so a re-invoked parent descends into the
child and finds everything up to date — the child resumes at its first
missing artifact instead of replanning from scratch. Timestamp semantics, the
same trick `board.mk` uses, stretched across a process boundary.

## Nested census — the tools recurse with the tree

Progress, graph, and wfcheck all follow the recursion, each with the smallest
mechanism that stays truthful.

`make progress` prints the parent's own bar, then walks the plan's composite
components and runs `$(MAKE) -s -C src/<id> progress` for each, indenting the
child's output. There is deliberately *no* merged whole-tree percentage: a
single number averaging levels of wildly unequal cost would lie, so each level
reports its own bar. A composite that is planned but not yet scaffolded prints
as `(subtree, not scaffolded)` — the honest rendering of lazy planning, since
an unplanned subtree has no leaf count yet to report against.

`make graph` wraps each subtree's diagram in a mermaid `subgraph` block and
prefixes the child's node ids with the component id (`build/plan.json` →
`api-layer/build/plan.json`). Without that namespacing mermaid would merge
identically-named nodes from different subtrees into one. A final edge from
the child's `report.md` to the parent's `.done` sentinel draws the verdict
bubble into the picture.

`wfcheck` re-invokes itself on each composite's directory — a subtree is
indistinguishable from a top-level project, so the same script applies
unchanged. Each subtree contributes exactly *one* check (`subtree:<id>`) to
its parent's score rather than flattening its own checks upward, so a
wide subtree cannot dilute a small parent's score; a parent passes only if
every subtree passes, recursively. Drill-down is preserved because every level
writes its own `build/wfscore.json`, and the parent's file carries a
`subtrees` summary map pointing at them. Flat projects hit none of these code
paths — their output stays byte-identical.
