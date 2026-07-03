# agentmake root — convenience targets only. The engine is engine/build.mk.
# Default work queue: the Backlog.md board (engine/board.mk) — make board-next.
DEMO ?= game-of-life

.PHONY: demo demo-resume
demo:  ## fresh engine run of demos/$(DEMO) — needs pi (or claude) CLI + API key
	$(MAKE) -C demos/$(DEMO) clean
	$(MAKE) -C demos/$(DEMO) -j2 all
	$(MAKE) -C demos/$(DEMO) progress
	$(MAKE) -C demos/$(DEMO) graph

demo-resume:  ## same, but without the clean — resumes wherever it stopped
	$(MAKE) -C demos/$(DEMO) -j2 all
	$(MAKE) -C demos/$(DEMO) progress

include engine/board.mk  # board targets last — keeps `make` == `make demo`
