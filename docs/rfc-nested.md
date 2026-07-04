# RFC nested — hierarchical decomposition via recursive make (FINAL)

Status: adjudicated spec (dueling-designs round, TASK-11). Supersedes and
replaces scratch RFCs nested-A (recursive make) and nested-B
(flatten-at-generate).

> Post-implementation note: the per-subtree classify *agent* described below
> was since replaced by an explicit `TIER` param (`--budget`, d4d5def); the MAXTIER
> clamp survives as a deterministic jq rule in `engine/build.mk`. §5b/§6
> record the agent-era mechanics.

## Adjudication record

**Winner: A (recursive make), with two grafts from B.**

Criteria weighted for long-running trajectories:

| criterion | A | B | notes |
|---|---|---|---|
| resume after interrupt at depth 2+ (HIGH) | pass | pass | B simpler (flat sentinels); A's timestamp cascade + cmp-guard verified sound |
| lazy planning (HIGH) | **win** | lose | B concedes (its cons #1/#2): all sub-plans upfront, blind to built reality |
| -j utilization across subtrees | lose | win | A: cross-subtree deps inexpressible; B: one pool, whole DAG |
| census truthfulness mid-flight | lose | win | B: flat census free; A: per-level bars, recursion in 3 tools |
| impl size | lose | win | B leaves wfcheck/progress untouched |
| make -n debuggability | lose | win | B: one components.mk = whole story |

B won 4/6 but lost the criterion the mission exists for. Mission: "one plan
call cannot foresee a big build; long runs re-plan as reality shifts." B
replaces one blind upfront plan with N blind upfront plans — same failure
mode, more calls. B's own rejected variant B2 (make re-include restart chain)
proves lazy planning structurally impossible inside a single make instance:
make remakes all included makefiles before building anything. A plans each
subtree at build time, after its dependencies exist — the only design where
reality can inform the plan. A's losses are quality-of-life
(log soup, census recursion, larger diff); B's loss is the mission.

**Grafts from B (both cheap, both close A's worst cons):**

1. **Tier ceiling** (B §5 insight, promotes A's own §6 "upgrade path" to v1):
   subtree classify clamped to parent tier. Closes A's classifier-gaming /
   prd-cascade cost-blowup con.
2. **Per-level fanout gate** (B con-8 recommendation): plan gate enforces
   `components|length <= MAXFANOUT`. Tree bounded by MAXFANOUT^MAXDEPTH,
   deterministically.

Explicitly rejected from B: flatten-at-generate itself (loses lazy planning);
`engine/expand` (unneeded — recursion is make's job); dot-namespaced flat ids
(unneeded — subtree dirs namespace for free).

## Shape in one paragraph

Composite component = full create-mvp project nested at `src/<id>/`. Parent's
generated rule scaffolds `goal.md` + 3-line Makefile + delegating `check.sh`,
then `+$(MAKE) -C src/<id> all`. Subtree runs the SAME pipeline (classify →
plan → components → review) via the same `engine/build.mk`. Parent sentinel
`build/<id>.done` created iff subtree review printed `VERDICT: PASS` —
verdict bubbles through the delegating `check.sh`, so the parent-level
invariant (*.done exists iff built AND verified*) holds unchanged. Recursion
bounded by `AGENTMAKE_DEPTH`/`AGENTMAKE_MAXDEPTH` (default 3), enforced
deterministically in the jq template, not by prompt trust. Subtree tier
bounded by parent tier via `MAXTIER` clamp.

Core bet: subtree == project. Zero new pipeline concepts; `board.mk` already
proves the `$(MAKE) -C dir all` pattern.

## 1. plan.json schema delta

```json
{"components":[{
  "id":"kebab-case",
  "desc":"what to build, concrete",
  "deps":["ids of components this needs"],
  "kind":"leaf|composite",
  "sub_goal":"markdown goal spec for the subtree — required iff kind==composite"
}]}
```

- `kind` optional, absent ⇒ `"leaf"`. Old plans parse unchanged; wfcheck
  `plan-schema` / `dag-valid` already tolerate extra fields (verified in recon).
- `sub_goal` = self-contained goal text. `desc` STAYS mandatory and must
  describe a buildable unit even for composites — it is the fallback when the
  depth cap forces leaf, and the integration contract siblings read from
  `plan.json`.
- Rejected alternative: `needs_decomposition: true` without `sub_goal` (child
  re-derives goal from desc) — desc is one sentence; the planner has the
  context NOW; make it write the sub-goal while it's cheap.

Plan gate in `build.mk` grows three clauses (composite⇒sub_goal; fanout
ceiling — graft 2; id/dep charset allowlist — ids are spliced verbatim into
makefile targets and shell recipe lines by the jq template, and LLM output is
a trust boundary, same doctrine as §5b):

```make
MAXFANOUT ?= 8   # top of prd fanout range; per-level tree-width insurance

$(B)/plan.json: $(GOAL) $(B)/effort.json
	$(AGENT) plan $< > $@
	jq -e --argjson maxf $(MAXFANOUT) 'def okid: type=="string" and test("^[a-z0-9][a-z0-9-]{0,63}$$");
	  (.components | length > 0 and length <= $$maxf) and all(.components[];
	  (.id|okid) and all(.deps[]?; okid) and
	  ((.kind // "leaf") == "leaf" or (.sub_goal | type=="string" and length > 0))
	)' $@ > /dev/null   # gate: bounded fanout; composite ⇒ sub_goal; id/dep charset
```

## 2. Layout — composite lives at `src/<id>/`

```
src/<id>/
  goal.md        # written by parent from .sub_goal (cmp-guarded mtime)
  Makefile       # scaffold: GOAL ?= goal.md / include <ABS_ENGINE>/build.mk
  check.sh       # delegating gate: grep VERDICT: PASS build/report.md
  build/         # subtree's own effort.json plan.json *.done report.md
  src/           # subtree's own components (recursion here)
```

Why here and not `runs/<id>` etc. — recon landmine 4 resolves in our favor:

- review rubric globs `$SRC/*/check.sh` → delegating check.sh sits at exactly
  that path → **review works unchanged** (reviewer can also read
  `src/<id>/build/report.md` for drill-down).
- wfcheck `src:<id>` (non-empty dir), `checksh:<id>` (executable),
  `run:<id>` (exit 0 iff subtree verdict PASS) → **all three pass without
  wfcheck changes** at the parent level. No 3-false-FAILs problem.
- `SIBLINGS=$(ls $SRC)` in build role → composite shows up as a sibling name.
  Correct: leaf builders may integrate against it.
- `clean` (`rm -rf $B $SRC`) → recursion nuked for free.

Delegating check.sh (scaffolded, exact contents):

```bash
#!/bin/bash
# composite gate: done iff subtree review verdict PASS
cd "$(dirname "$0")" && grep -q '^VERDICT: PASS$' build/report.md
```

Instant grep — immune to wfcheck `CHECK_TIMEOUT`.

## 3. build.mk changes

### 3a. Depth + ceiling vars

```make
AGENTMAKE_DEPTH    ?= 0
AGENTMAKE_MAXDEPTH ?= 3
MAXTIER            ?= prd   # graft 1: subtree classify ceiling; root unbounded
export AGENTMAKE_DEPTH AGENTMAKE_MAXDEPTH MAXTIER   # agent roles read these
NEXT_DEPTH := $(shell expr $(AGENTMAKE_DEPTH) + 1)
AT_CAP     := $(shell [ $(AGENTMAKE_DEPTH) -ge $(AGENTMAKE_MAXDEPTH) ] && echo 1 || echo 0)
```

Export feeds the agent subprocess (prompt conditional, §5). It does NOT feed
child make — recon landmine 3: env-origin loses to nothing, child `?=` would
be silently skipped and depth would never increment. Depth and tier ceiling
are therefore passed **on the `$(MAKE)` command line** (strongest origin,
also beats MAKEFLAGS-propagated assignments from higher levels).

### 3b. jq template — the fork point

```make
$(B)/components.mk: $(B)/plan.json
	jq -r --arg cap "$(AT_CAP)" '.components[] |
	  "$(B)/\(.id).done: $(B)/plan.json \(.deps | map("$(B)/\(.).done") | join(" "))\n"
	  + (if (.kind // "leaf") == "composite" and $$cap != "1" then
	       "\t$$(ENGINE)subtree \(.id)\n\t+$$(MAKE) -C $(SRC)/\(.id) GOAL=goal.md B=build SRC=src AGENTMAKE_DEPTH=$(NEXT_DEPTH) MAXTIER=$$$$(jq -r .tier $(B)/effort.json) all\n"
	     else
	       "\t$$(AGENT) build \(.id)\n"
	     end)
	  + "\tbash $(SRC)/\(.id)/check.sh\n\ttouch $$@\nCOMPONENTS += $(B)/\(.id).done\n"' $< > $@
```

Generated composite rule (concrete, what lands in components.mk):

```make
build/api-layer.done: build/plan.json build/schema.done
	$(ENGINE)subtree api-layer
	+$(MAKE) -C src/api-layer GOAL=goal.md B=build SRC=src AGENTMAKE_DEPTH=1 MAXTIER=$$(jq -r .tier build/effort.json) all
	bash src/api-layer/check.sh
	touch $@
COMPONENTS += build/api-layer.done
```

Line-by-line landmine accounting:

- `+$(MAKE)` — literal `$(MAKE)` (jq `$$(MAKE)`) + `+` prefix ⇒ jobserver fds
  inherited via MAKEFLAGS, no explicit `-jN` at any nested level. Top-of-tree
  `-jN` (e.g. board.mk's `-j$(BOARD_JOBS)`) budgets the WHOLE tree. Landmine 1
  closed.
- `GOAL=goal.md B=build SRC=src` on the command line — kills the
  `export GOAL B SRC` env leak (landmine 3). Parent running with `B=out`
  no longer poisons children.
- `MAXTIER=$$(jq -r .tier build/effort.json)` — shell substitution at recipe
  run time (jq emits `$$$$` → makefile `$$(...)` → shell `$(...)`); parent's
  own classified tier becomes the child's ceiling. Command-line origin, same
  reasoning as depth.
- `$$cap` (not `$cap`) inside the recipe — make would eat `$c` otherwise.
- `AT_CAP=1` ⇒ jq emits the LEAF branch regardless of what the planner said.
  Deterministic depth bound; prompt conditional (§5) is optimization, this is
  the enforcement. Forced leaf builds from `desc` (mandatory per §1).
- Uniform tail (`check.sh` + `touch`) for both kinds — sentinel semantics and
  `.DELETE_ON_ERROR` behavior identical for leaf and composite.
- `.DELETE_ON_ERROR` scope per make instance (landmine 2): child failure fails
  the parent recipe before `touch`, parent sentinel never exists; child's own
  instance protects child artifacts. Nothing to fix.

## 4. `engine/subtree` — scaffold helper (new file, exact contents)

Ponytail call: 6-line recipe with nested quoting inside a jq string is
escaping misery; a helper script IS the minimum code. It also gives us the
absolute engine path for free (`dirname $0`), closing landmine 8 (nested
relative `include ../../engine/build.mk` breaks at depth ≥ 2).

```bash
#!/bin/bash
# subtree <id> — scaffold composite component project dir. Idempotent, resume-safe.
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)   # absolute engine dir
B=${B:-build} SRC=${SRC:-src}
id=$1
# trust boundary (same allowlist as build.mk plan gate): id becomes a path
# component + shell arg — reject metachars/traversal even when called directly
[[ $id =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || { echo "subtree: invalid id: $id" >&2; exit 1; }
d=$SRC/$id
mkdir -p "$d"

# goal.md from plan.json .sub_goal — cmp guard preserves mtime (board.mk trick):
# unchanged sub_goal ⇒ untouched mtime ⇒ child make resumes instead of replanning
jq -r --arg id "$id" '.components[] | select(.id==$id) | .sub_goal // empty' "$B/plan.json" > "$d/goal.md.new"
grep -q '[^[:space:]]' "$d/goal.md.new" || { echo "subtree: empty sub_goal for $id" >&2; exit 1; }
if cmp -s "$d/goal.md.new" "$d/goal.md" 2>/dev/null; then rm "$d/goal.md.new"; else mv "$d/goal.md.new" "$d/goal.md"; fi

[ -f "$d/Makefile" ] || printf 'GOAL ?= goal.md\ninclude %s/build.mk\n' "$DIR" > "$d/Makefile"

if [ ! -x "$d/check.sh" ]; then
  printf '#!/bin/bash\n# composite gate: done iff subtree review verdict PASS\ncd "$(dirname "$0")" && grep -q '\''^VERDICT: PASS$'\'' build/report.md\n' > "$d/check.sh"
  chmod +x "$d/check.sh"
fi
```

Child Makefile stays the sacred 3-line contract, engine path absolute:

```make
GOAL ?= goal.md
include /abs/path/to/engine/build.mk
```

(Child's `ENGINE := $(dir $(lastword $(MAKEFILE_LIST)))` recomputes correctly
from the absolute include — plain `:=` assignment, immune to env leakage.)

## 5. engine/agent — role deltas

### 5a. plan role

```bash
plan)
    export GOAL_TEXT="$(cat "$1")" FANOUT="$(knob fanout "3-5")"
    if [ "${AGENTMAKE_DEPTH:-0}" -lt "${AGENTMAKE_MAXDEPTH:-3}" ]; then
      export COMPOSITE_RULES='A component too large for one focused build session may set "kind":"composite" with "sub_goal": a self-contained goal spec (markdown, own acceptance criteria) for recursive decomposition. Use sparingly — most components are leaves.'
    else
      export COMPOSITE_RULES='Every component MUST be a leaf: omit "kind" or set "kind":"leaf". Composite is forbidden at this depth.'
    fi
    run plan no "$(render plan.md)" | sed '/^```/d'
    ;;
```

`prompts/plan.md` delta — schema line + one rule:

```
{"components":[{"id":"kebab-case","desc":"what to build, concrete","deps":["ids of components this needs"],"kind":"leaf|composite (optional, default leaf)","sub_goal":"required iff composite: full goal spec for the subtree"}]}
Rules: deps may only reference other listed ids; honor tech constraints stated in the goal; each leaf independently checkable via a non-interactive self-test. ${COMPOSITE_RULES}
```

### 5b. classify role — tier ceiling clamp (graft 1)

Deterministic post-process, never stalls the pipeline (unlike a gate that
hard-fails on classifier disobedience). Clamps the WHOLE knob row, not just
the tier string — a clamped tier with prd fanout/model would defeat the point:

```bash
classify)
    ...existing run...  | jq --arg max "${MAXTIER:-prd}" '
      def r: {"vague":0,"standard":1,"prd":2};
      def row: {"vague":  {tier:"vague",   fanout:"2-3",review_depth:"smoke",   model_hint:"small",  thinking:"low"},
                "standard":{tier:"standard",fanout:"3-5",review_depth:"standard",model_hint:"default",thinking:"medium"}};
      if r[.tier] > r[$max] then row[$max] else . end'
    ;;
```

(Rows mirror the doctrine table in build.mk's header comment; prd row absent
because prd is never a clamp target.) Prompt belt optional: classify.md may
render "hard ceiling: tier must not exceed ${MAXTIER}" — the jq clamp is the
enforcement either way. LLM output is a trust boundary.

`build` and `review` roles: **unchanged** (§2 layout makes both work as-is).

## 6. Effort: re-classify per subtree, clamped

**Re-classify.** Each subtree runs its own `classify` because `effort.json`
is already a prerequisite of everything in `build.mk` — inheritance would
require NEW plumbing (copy parent effort.json into child, suppress child
classify rule); re-classification requires ZERO code. Justification beyond
laziness:

1. Doctrine applies recursively: "agent effort ∝ effort in goal text". The
   sub_goal is a fresh goal text; its spec quality legitimately varies
   independent of the parent's. A planner that writes a detailed sub_goal with
   acceptance criteria BUYS its subtree a bigger budget (up to the parent's
   tier). That's an incentive we want, not a bug.
2. classify is the cheapest call in the pipeline ("cheap call; gates whole
   pipeline") — per-composite overhead is one small no-tools call.
3. Uniformity: subtree is indistinguishable from a top-level project — every
   eval (wfcheck, snap, matrix) applies to a subtree dir without special
   cases.

The old risk (agent-authored sub_goals skew structured ⇒ classifier inflates
tier ⇒ unbounded prd cascades) is CLOSED by the MAXTIER clamp (§5b): a
subtree can never exceed its parent's tier. Monotone non-increasing effort
down the tree; cost worst case = parent tier × MAXFANOUT^MAXDEPTH leaves,
both factors now deterministic.

## 7. Resume semantics mid-subtree

Pure timestamp logic, no new state:

- Child leaf fails → child `.done` deleted by child's `.DELETE_ON_ERROR`,
  siblings' `.done` persist → child `all` fails → parent composite recipe
  fails before `touch` → parent `.done` absent (nothing partial to delete).
- Rerun parent `make all` → composite rule refires → `subtree <id>` is a
  no-op (cmp guard: goal.md mtime untouched; Makefile/check.sh exist) →
  child make resumes exactly at the failed leaf. Board contract preserved:
  task stays "In Progress", rerun continues.
- Parent `goal.md` edited → parent `plan.json` regenerates → all parent
  `.done` stale → composite rules refire → IF `.sub_goal` text changed, cmp
  guard swaps child `goal.md` → child effort/plan/components cascade rebuilds
  (correct); IF unchanged, child `all` is up-to-date and the refire costs one
  check.sh grep + touch (cheap).
- Completed subtree, parent re-invoked: `+$(MAKE) -C` runs, child reports
  "Nothing to be done", check.sh greps PASS, sentinel touched. Idempotent.

This is where lazy planning pays: a subtree interrupted BEFORE its plan
exists costs nothing on resume — no stale sub-plan to reconcile; the plan is
made when the trajectory next reaches it, with whatever reality then holds
(deps built, parent plan possibly revised).

## 8. Failure bubbling

Single mechanism, N levels: **non-zero exit crosses each make boundary; the
verdict grep is the semantic gate.**

```
grandchild check.sh exit≠0
→ grandchild .done absent (its .DELETE_ON_ERROR)
→ grandchild `all` fails → child composite recipe fails at +$(MAKE) line
→ child <id>.done absent → child review never runs → child `all` fails
→ parent composite recipe fails → parent .done absent → board task In Progress
```

Second failure mode: subtree BUILDS everything but its review says
`VERDICT: FAIL` → grep in child's report.md rule fails → child
`.DELETE_ON_ERROR` deletes report.md → child `all` fails → same bubble.
Delegating check.sh is a belt-and-braces re-check of the same verdict at the
parent boundary (protects against hand-touched sentinels / partial dirs).

Error attribution: GNU make prints `make[N]: *** [target] Error 1` per level —
the `[N]` + target path IS the breadcrumb. Ugly but honest (see cons).

## 9. Observability

### 9a. progress — nested, per-level bars

Append to the existing `progress` recipe (after the bar):

```make
	@for d in $$(jq -r '.components[] | select((.kind // "leaf")=="composite") | .id' $(B)/plan.json 2>/dev/null); do \
	  [ -f $(SRC)/$$d/Makefile ] || { printf ' \033[2m·\033[0m %s (subtree, not scaffolded)\n' $$d; continue; }; \
	  echo " └─ $$d:"; \
	  $(MAKE) -s -C $(SRC)/$$d progress | sed 's/^/    /'; \
	done
```

Output: parent bar, then indented child bars recursively. The
"not scaffolded" marker is the honest rendering of lazy planning: an
unplanned subtree has no leaf count yet, so no bar can truthfully include it.
ponytail: NO global percent rollup — a single merged number across levels of
unequal-cost components would lie; per-level bars are honest. Upgrade path:
emit progress.json per level, aggregate with jq (docs/dogfood/progress-json
groundwork).

### 9b. graph — mermaid subgraphs

Append to `graph` recipe:

```make
	@for d in $$(jq -r '.components[] | select((.kind // "leaf")=="composite") | .id' $(B)/plan.json 2>/dev/null); do \
	  [ -f $(SRC)/$$d/Makefile ] || continue; \
	  echo "  subgraph $$d"; \
	  $(MAKE) -s -C $(SRC)/$$d graph | tail -n +2 | sed -e "s|build/|$$d/build/|g" -e "s|^  goal.md|  $$d/goal.md|" -e 's/^/  /'; \
	  echo "  end"; \
	  echo "  $$d/build/report.md --> $(B)/$$d.done"; \
	done
```

`tail -n +2` strips the child's `graph TD` header; sed namespaces child node
ids (`build/plan.json` → `api-layer/build/plan.json`) — without it mermaid
MERGES identically-named nodes across subtrees. Edge from child report.md to
parent sentinel shows the bubble. ponytail: sed-prefix namespacing; ceiling =
id tokens containing `build/` substrings collide; upgrade = makefile2graph
(already the documented upgrade for graph).

### 9c. wfcheck — recurse + per-level score

Parent-level checks pass TODAY for composites (§2: src/checksh/run all
satisfied by the delegating layout). Recursion adds nested census. Delta:

```bash
# top of script, before cd "$proj":
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

# after the per-component loop, before the review gate:
for id in $(jq -r '.components[]? | select((.kind // "leaf")=="composite") | .id' "$plan" 2>/dev/null); do
  if "$self" "$SRC/$id" >/dev/null 2>&1; then
    record "subtree:$id" 1 "$(jq -r '"\(.passed)/\(.total) score \(.score)"' "$SRC/$id/$B/wfscore.json")"
  else
    record "subtree:$id" 0 "$(jq -r '"\(.passed)/\(.total) score \(.score)"' "$SRC/$id/$B/wfscore.json" 2>/dev/null || echo 'subtree wfcheck did not produce wfscore.json')"
  fi
done
```

Score aggregation decision: **per-level score; `subtree:<id>` counts as ONE
check in the parent.** No flat summing of nested checks into the parent
score — a fanout-8 subtree would otherwise dominate a 4-component parent
(score dilution + partial double-count with `run:<id>`). Drill-down preserved:
child writes its own `src/<id>/build/wfscore.json`; parent wfscore.json
assembly gains a pointer map:

```bash
# assemble step addition:
jq -s '{checks:., passed:(map(select(.pass))|length), total:length}
       | .score = ((.passed/.total*100|round)/100)' "$results" \
| jq --argjson subs "$(jq -n '[inputs | {(input_filename | sub("/'"$B"'/wfscore.json$";"") | sub("^.*/";"")): {score, passed, total}}] | add // {}' $SRC/*/$B/wfscore.json 2>/dev/null || echo '{}')" \
     '. + {subtrees: $subs}' > "$B/wfscore.json"
```

Semantics: parent PASS requires every `subtree:<id>` PASS requires child
wfcheck exit 0 recursively — full-tree exit code unchanged in meaning.

## 10. Honest cons (post-graft)

1. **Recursive make classic**: make never sees the whole DAG. Cross-subtree
   deps are INEXPRESSIBLE — a grandchild cannot depend on an uncle. Dep edges
   exist only within one plan.json. Integration contracts weaken with depth
   (child builder reads its own plan.json + SIBLINGS one level up, nothing
   above that). Structural price of lazy planning; the flatten design (B)
   traded the reverse way and lost the duel on it.
2. **Jobserver is inherited, not partitioned**: top `-j2` means 2 recipe slots
   ACROSS the whole tree (make releases the token while a `+$(MAKE)` sub-make
   runs, so composite recipes don't pin slots), but long-lived nested agents
   at depth 3 still serialize badly behind small top-level -j. Tuning -j now
   requires thinking about tree width at every level, not one flat fanout.
3. **N make instances**: MAKELEVEL 0..3, interleaved `make[2]:`/`make[3]:`
   output under -j is log soup; failure forensics = walking nested dirs.
   Memory/process overhead trivial; readability overhead real.
4. **Agent-call multiplier**: each composite = +classify +plan +review (3
   calls) before any building; reviews run serially at subtree unwind.
   Post-graft the multiplier is BOUNDED (MAXTIER monotone non-increasing,
   MAXFANOUT per level, MAXDEPTH global) but not eliminated — tree shape
   still costs, planner still controls shape within the bounds.
5. **Census complexity tax**: progress/graph/wfcheck all grew recursion +
   namespacing + skip-if-not-scaffolded logic. Three tools, three recursion
   implementations (make-loop, make-loop+sed, bash self-invoke). Drift risk
   between them.
6. **Depth cap forces leaf with composite-grade desc**: at AT_CAP the original
   problem (giant single agent call) reappears at the boundary — mitigated,
   not solved.
7. **plan.json refire cost**: parent replan touches plan.json ⇒ every
   composite recipe refires (scaffold no-op + child up-to-date walk + grep) —
   cheap but O(tree) process spawns on any parent edit.
8. **Env leakage foot-gun is permanent**: any FUTURE `export` added to
   build.mk silently inherits into all children; every exported var must be
   audited against `?=` in child scope. Convention ("pass overrides on the
   $(MAKE) line"), not a mechanism.

Closed by grafts (kept for the record): ~~classifier gaming / unbounded
prd-tier cascades~~ (MAXTIER clamp, §5b); ~~pathological fanout×depth leaf
explosion~~ (MAXFANOUT gate, §1).

## 11. Change inventory

| file | change |
|---|---|
| `engine/prompts/plan.md` | schema + `${COMPOSITE_RULES}` |
| `engine/agent` | plan role: depth-conditional `COMPOSITE_RULES` export; classify role: MAXTIER jq clamp |
| `engine/build.mk` | depth + MAXTIER + MAXFANOUT vars; plan gate clauses; jq template fork; progress + graph recursion |
| `engine/subtree` | NEW ~30-line scaffold helper |
| `evals/wfcheck` | `$self` capture; subtree loop; `.subtrees` in wfscore.json |
| `engine/prompts/build.md`, `review.md`, `classify.md`\*, `board.mk` | **unchanged** (\*optional MAXTIER belt clause) |

Smallest honest test: fixture plan.json with one composite + one leaf, run
`make all` with a stub AGENT, assert nested `build/report.md` + parent
sentinel + wfcheck PASS; then break the grandchild check.sh and assert the
bubble (parent exit ≠ 0, sentinel absent, resume rebuilds only the leaf).
Clamp check: stub classifier returning prd under `MAXTIER=vague`, assert
emitted effort.json is the vague row.

## 12. Deferred (post-v1, recorded from the duel)

- **SIBLINGS prefix filter** (from B con 5, applies to A too at high fanout):
  if build-prompt context bloats, filter `ls $SRC` — one line when it hurts.
- **progress.json rollup**: per-level JSON + jq aggregation for a truthful
  whole-tree leaf census (recovers B's census win without flattening).
- **review_depth interaction**: parent full review re-runs each
  `$SRC/*/check.sh` — for composites that's the cheap grep, so parent review
  does NOT re-inspect subtree code. Currently treated as a feature (bounded
  review scope, per-subtree reviews already gated); revisit if cross-subtree
  integration bugs slip through both levels.
- **Flatten hybrid**: if a future workload needs cross-subtree dep edges,
  B's expand-pre-pass can be layered UNDER this design (expand only subtrees
  already planned) — but no current demo needs it.
