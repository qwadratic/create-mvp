# engine-core: goal.md -> plan.json (gated) -> components.mk (re-included) -> stamps
SHELL := bash
.DELETE_ON_ERROR:
.DEFAULT_GOAL := all

ENGINE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
AGENT ?= $(ENGINE_DIR)../stub-agent/agent.sh
GATE  ?= $(ENGINE_DIR)../plan-gate/gate.sh
GEN   ?= $(ENGINE_DIR)../components-generator/generate.sh
GOAL  ?= goal.md

plan.json: $(GOAL)
	$(AGENT) plan $< > $@
	$(GATE) $@

components.mk: plan.json
	$(GEN) $< > $@

# make auto-rebuilds components.mk then restarts itself (re-include)
include components.mk

all: $(STAMPS)
.PHONY: all
