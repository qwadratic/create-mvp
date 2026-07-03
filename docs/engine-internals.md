# Engine internals: the make features doing the work

The whole engine is one file, [`engine/build.mk`](../engine/build.mk) (~80 lines).
Every feature below is stock GNU make — nothing is patched or wrapped. This doc
explains what each feature does here and why it earns its place. Excerpts are
verbatim from the engine.

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
	jq -e '.components | length > 0' $@ > /dev/null   # gate: valid decomposition
```

If the `jq -e` check fails, the recipe fails, `plan.json` is deleted, and the
pipeline stops — an invalid decomposition cannot leak downstream. The same
pattern gates the effort classifier (schema check), every component
(`check.sh`), and the final review (`grep -q 'VERDICT: PASS'`).

## `-include` + generated `components.mk` — the agent-shaped DAG

Make has a little-known superpower: if an included makefile is out of date and
there is a rule to rebuild it, make rebuilds it and **restarts itself** with
the new content. The engine uses this so the dependency graph itself comes
from the planning agent:

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
