# agentmake engine — goal.md → effort → plan → components (parallel, dep-ordered) → review gate
#
# Effort classifier (Phase 0): agent effort ∝ user effort in goal.md.
#   tier     | fanout | review_depth | model_hint | thinking
#   vague    | 2-3    | smoke        | small      | low
#   standard | 3-5    | standard     | default    | medium
#   prd      | 5-8    | full         | large      | high
# Consumption: fanout → plan prompt component count; model_hint/thinking →
#   pi flags (--model via MODEL_SMALL/MODEL_LARGE env, --thinking direct);
#   review_depth → review rubric (smoke: check.sh only … full: evals mandatory).
#
# Project Makefile is 3 lines:
#   GOAL ?= goal.md        # optional overrides: GOAL, B, SRC, AGENT
#   include engine/build.mk
#
SHELL := /bin/bash
.DELETE_ON_ERROR:  # failed agent ≠ done artifact

ENGINE := $(dir $(lastword $(MAKEFILE_LIST)))
GOAL  ?= goal.md
B     ?= build
SRC   ?= src
AGENT ?= $(ENGINE)agent
export GOAL B SRC   # agent adapter reads these

.PHONY: all progress graph clean

all: $(B)/report.md

# ── Phase 0: effort classification (cheap call; gates whole pipeline)
$(B)/effort.json: $(GOAL) | $(B)
	$(AGENT) classify $< > $@
	jq -e '(.tier|IN("vague","standard","prd")) and (.fanout|test("^[0-9]+-[0-9]+$$")) and (.review_depth|IN("smoke","standard","full")) and (.model_hint|IN("small","default","large")) and (.thinking|IN("off","low","medium","high"))' $@ > /dev/null   # gate: schema

# ── Phase 1: decomposition (agent, no tools)
$(B)/plan.json: $(GOAL) $(B)/effort.json
	$(AGENT) plan $< > $@
	jq -e '.components | length > 0' $@ > /dev/null   # gate: valid decomposition

# ── Phase 2: plan generates the DAG — dep edges come from the agent
-include $(B)/components.mk
$(B)/components.mk: $(B)/plan.json
	jq -r '.components[] | "$(B)/\(.id).done: $(B)/plan.json \(.deps | map("$(B)/\(.).done") | join(" "))\n\t$$(AGENT) build \(.id)\n\tbash $(SRC)/\(.id)/check.sh\n\ttouch $$@\nCOMPONENTS += $(B)/\(.id).done\n"' $< > $@

# ── Phase 3: reviewer agent gate
# components.mk prereq: without it, a failed plan/effort gate leaves COMPONENTS
# empty and review would run against nothing (-include hides remake failure)
$(B)/report.md: $(B)/components.mk $(COMPONENTS)
	$(AGENT) review > $@
	grep -q 'VERDICT: PASS' $@

$(B):
	mkdir -p $@

# ── Observability
ARTIFACTS = $(B)/effort.json $(B)/plan.json $(COMPONENTS) $(B)/report.md
progress:
	@done=0; total=0; \
	for f in $(ARTIFACTS); do \
	  total=$$((total+1)); \
	  if [ -f $$f ]; then done=$$((done+1)); printf ' \033[32m✓\033[0m %s\n' $$f; \
	  else printf ' \033[2m·\033[0m %s\n' $$f; fi; \
	done; \
	pct=$$((done*100/total)); n=$$((done*24/total)); \
	bar=""; [ $$n -gt 0 ] && bar=$$(printf '#%.0s' $$(seq 1 $$n)); \
	printf '[%-24s] %d/%d (%d%%)\n' "$$bar" $$done $$total $$pct
# nested: per-level bars, no global rollup — merged percent across unequal-cost
# subtrees would lie; "not scaffolded" = honest rendering of lazy planning
	@for d in $$(jq -r '.components[] | select((.kind // "leaf")=="composite") | .id' $(B)/plan.json 2>/dev/null); do \
	  [ -f $(SRC)/$$d/Makefile ] || { printf ' \033[2m·\033[0m %s (subtree, not scaffolded)\n' $$d; continue; }; \
	  echo " └─ $$d:"; \
	  $(MAKE) -s -C $(SRC)/$$d progress | sed 's/^/    /'; \
	done

# ponytail: awk-parsed mermaid; ceiling = pattern/order-only deps; upgrade = makefile2graph
graph:
	@echo 'graph TD'; \
	awk -F: '/^[a-zA-Z$$(][^=]*:([^=]|$$)/ && $$1!~/PHONY|DELETE_ON_ERROR/ \
	  {t=$$1; n=split($$2,d," "); for(i=1;i<=n;i++) if(d[i]!="|") printf "  %s --> %s\n", d[i], t}' \
	  $(ENGINE)build.mk $(B)/components.mk 2>/dev/null | sed -e 's/$$(B)/$(B)/g' -e 's/$$(GOAL)/$(GOAL)/g'
# nested: subgraph per composite; sed namespaces child node ids or mermaid
# merges identically-named nodes across subtrees; last edge shows the bubble
	@for d in $$(jq -r '.components[] | select((.kind // "leaf")=="composite") | .id' $(B)/plan.json 2>/dev/null); do \
	  [ -f $(SRC)/$$d/Makefile ] || continue; \
	  echo "  subgraph $$d"; \
	  $(MAKE) -s -C $(SRC)/$$d graph | tail -n +2 | sed -e "s|build/|$$d/build/|g" -e "s|^  goal.md|  $$d/goal.md|" -e 's/^/  /'; \
	  echo "  end"; \
	  echo "  $$d/build/report.md --> $(B)/$$d.done"; \
	done

clean:
	rm -rf $(B) $(SRC)
