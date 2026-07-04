# zero-key demo: same engine, same gates, deterministic mock agent (no LLM).
# AGENT set before the include so it beats the engine's ?=; exported + absolute
# so the composite subtree recursion (make -C src/comp) inherits it too.
GOAL ?= goal.md
export AGENT ?= $(abspath ../../engine/fixtures/mock-agent)
include ../../engine/build.mk
