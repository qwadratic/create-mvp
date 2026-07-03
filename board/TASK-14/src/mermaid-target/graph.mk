# include from engine Makefile; expects PLAN (default plan.json)
PLAN ?= plan.json
GRAPH_SH := $(dir $(lastword $(MAKEFILE_LIST)))graph.sh

.PHONY: graph
graph:
	@$(GRAPH_SH) $(PLAN)
