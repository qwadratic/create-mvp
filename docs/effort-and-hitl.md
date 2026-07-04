# Effort classification and the human-in-the-loop switch

Two control planes sit on top of the pipeline: an **effort classifier**
scaling agent spend to how much the human invested in the goal, and a single
**HITL switch** flipping any step between auto and human approval.

## Effort tiers: agent effort ∝ user effort

Phase 0 of every run is one cheap agent call: classify `goal.md`, write
`build/effort.json`. The result is schema-gated with `jq -e` before anything
else runs — a malformed classification kills the pipeline, not just warns.

| tier | goal looks like | fanout | review_depth | model_hint | thinking |
|---|---|---|---|---|---|
| `vague` | one-liner, no constraints ("make me a todo app") | 2–3 | smoke | small | low |
| `standard` | named features, tech constraints, rough structure | 3–5 | standard | default | medium |
| `prd` | acceptance criteria, structured sections, edge cases | 5–8 | full | large | high |

Where each knob lands:

- **fanout** → injected into the plan prompt as the allowed component count,
  so a one-liner doesn't fan out into eight agents.
- **model_hint** → `small`/`large` resolve through the `MODEL_SMALL` /
  `MODEL_LARGE` environment variables (unset → provider default); `default`
  passes no flag.
- **thinking** → passed straight to the runtime (`pi --thinking …`, mapped to
  `--effort` for the claude CLI).
- **review_depth** → selects the reviewer's rubric: `smoke` runs each
  `check.sh` and judges by exit codes; `standard` also inspects code; `full`
  verifies every acceptance criterion and makes evals mandatory (missing or
  failing evals = FAIL).

The classifier's exact rubric:
[`engine/prompts/classify.md`](../engine/prompts/classify.md); knob plumbing:
[`engine/agent`](../engine/agent). `effort.json` also accepts hand-authored
per-unit overrides (`units: {"plan": "high", "<component-id>": "low"}` plus a
`tiers` map to models/thinking) to route one hard component to a bigger model
without upgrading the whole run.

## The HITL switch: approval is a file

Design goal: one mechanism flipping any step — or the whole project —
between autopilot and human approval, without leaving make. Full design
discussion (alternatives rejected: interactive `read`, `ifeq` per recipe,
`.WAIT`, external CI approvals):
[`evals/docs/DRIFT-DESIGN.md`](../evals/docs/DRIFT-DESIGN.md) §2. This is the
mechanics summary.

**State model.** Step `X` already produces `build/X.done` (built and
self-checked). Add `build/approvals/X.ok` *depending on* `X.done`; point
downstream consumers at the `.ok` instead of the `.done`. Everything else
falls out of make's timestamp rules:

- approval exists ⇔ the `.ok` file exists — survives restarts, no daemon;
- rebuilding `X` makes `X.done` newer than `X.ok`: the gate **re-opens
  automatically** — no approval survives content that changed;
- the `.ok` content records who approved, when, and the sha256 of what they
  approved — audit trail included.

**Knobs** — all at invocation time, no Makefile edits:

```
make AUTOPILOT=1                 # whole project auto (default 0 = human)
make HUMAN_STEPS="http-api"      # force human on listed steps even under AUTOPILOT=1
make AUTO_STEPS="db-layer"       # force auto on listed steps even under AUTOPILOT=0
```

Precedence per step: `HUMAN_STEPS` > `AUTO_STEPS` > `AUTOPILOT`. One boolean,
two override lists, all funneling into one pattern rule:

```make
$(APPROVALS)/%.ok: $(B)/%.done | $(APPROVALS)
	@mode=$(if $(filter 1,$(AUTOPILOT)),auto,human); \
	case " $(AUTO_STEPS) "  in *" $* "*) mode=auto;;  esac; \
	case " $(HUMAN_STEPS) " in *" $* "*) mode=human;; esac; \
	if [ $$mode = auto ]; then \
	  $(AGENT) approve $* > $(APPROVALS)/$*.review; \
	  grep -q '^APPROVE' $(APPROVALS)/$*.review; \
	  { echo "approved-by: auto"; date -u +%FT%TZ; \
	    shasum -a 256 $(B)/$*.done; } > $@; \
	else \
	  echo "── HUMAN GATE: review src/$*/ then run: make approve-$*"; \
	  exit 1; \
	fi

approve-%: | $(APPROVALS)
	@test -f $(B)/$*.done || { echo "nothing to approve: $(B)/$*.done missing"; exit 1; }
	@{ echo "approved-by: $$USER"; date -u +%FT%TZ; \
	   shasum -a 256 $(B)/$*.done; } > $(APPROVALS)/$*.ok

unapprove-%:
	rm -f $(APPROVALS)/$*.ok

pending:
	@for f in $(B)/*.done; do s=$$(basename $$f .done); \
	  [ -f $(APPROVALS)/$$s.ok ] || echo "pending: make approve-$$s"; done
```

**How each path behaves:**

- *Auto* is a gate, not a rubber stamp: an approver agent inspects the
  artifact and must print a line starting `APPROVE`. Anything else fails the
  recipe, `.DELETE_ON_ERROR` removes the half-written `.ok`, the build stops.
  The agent's reasoning stays in `<step>.review` for audit.
- *Human* fails the target with printed instructions. Run `make -k` so one
  blocked gate doesn't stall parallel siblings — every reachable step still
  builds, every human gate prints its instruction, `make pending` lists the
  queue. Approve: `make approve-<step>`; rerunning `make` resumes where you
  left off. Revoke one gate: `make unapprove-<step>`; all of them:
  `rm -rf build/approvals`.

**Wiring into the engine.** The current `engine/build.mk` ships *without* the
approvals block — dependency edges go straight `.done → .done` (tracked as a
backlog task). Enabling it: a one-line change to the jq `components.mk`
generator (dep edges reference `$(B)/approvals/<dep>.ok` instead of
`$(B)/<dep>.done`) plus the rules above. The same pattern then covers
component gates, eval verdicts, and the final review with no additional
mechanism.
