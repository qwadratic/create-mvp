# agentmake board — Backlog.md is the engine's DEFAULT work queue.
#
# Why (docs/dogfood-autopsy.md): ad-hoc goal.md files don't scale — no queue,
# no lifecycle, clutter dir per idea. The board IS the goal source:
#   task = goal unit, status = lifecycle, backlog CLI = the only writer.
#
#   make board          list the board
#   make board-next     top "To Do" task -> board/<TASK-ID>/goal.md ->
#                       full pipeline -> gates pass -> task Done via CLI
#   make board-task TASK=TASK-7    same, explicit task
#
# Contract: task DESCRIPTION is the goal body (title becomes the h1).
# Acceptance criteria stay on the board — check them via the backlog CLI
# when the corresponding gate passes. Backlog CLI ONLY — never edit
# backlog/**/*.md directly.
#
# Failure honesty: a failed gate leaves the task "In Progress" and the run
# dir resumable — rerun `make board-task TASK=<id>` to continue; the task is
# only marked Done after `all` (review gate included) exits 0.
BOARD_RUNS ?= board
BOARD_JOBS ?= 2
BOARD_TODO ?= To Do

.PHONY: board board-next board-task

board:
	@backlog task list --plain

board-next:
	@id=$$(backlog task list --status "$(BOARD_TODO)" --plain | grep -oE '[A-Za-z]+-[0-9]+' | head -1); \
	if [ -z "$$id" ]; then echo 'board-next: no "$(BOARD_TODO)" tasks — board drained'; exit 0; fi; \
	echo "board-next: pulled $$id"; \
	$(MAKE) board-task TASK=$$id

# ponytail: parses `backlog task view --plain`; ceiling = CLI output format
# drift (fails loud on empty goal); upgrade = CLI JSON output when it grows one.
board-task:
	@test -n "$(TASK)" || { echo 'usage: make board-task TASK=TASK-N' >&2; exit 2; }
	@mkdir -p $(BOARD_RUNS)/$(TASK)
	@backlog task view $(TASK) --plain | awk '\
	  !t && /^Task [A-Za-z]+-[0-9]+ - / { t=1; sub(/^Task [A-Za-z]+-[0-9]+ - /,""); print "# " $$0; next } \
	  /^Description:$$/ { g=1; next } \
	  g && /^-+$$/ && !b { next } \
	  g && /^(Acceptance Criteria|Definition of Done|Implementation Plan|Implementation Notes|Comments|Final Summary):$$/ { exit } \
	  g { b=1; print }' > $(BOARD_RUNS)/$(TASK)/goal.md
	@grep -q '[^[:space:]]' $(BOARD_RUNS)/$(TASK)/goal.md || { echo "board-task: empty goal from $(TASK) — description missing?" >&2; exit 1; }
	@[ -f $(BOARD_RUNS)/$(TASK)/Makefile ] || printf 'GOAL ?= goal.md\ninclude ../../engine/build.mk\n' > $(BOARD_RUNS)/$(TASK)/Makefile
	backlog task edit $(TASK) -s "In Progress" --plain > /dev/null
	$(MAKE) -C $(BOARD_RUNS)/$(TASK) -j$(BOARD_JOBS) all
	$(MAKE) -C $(BOARD_RUNS)/$(TASK) progress
	backlog task edit $(TASK) -s Done --append-notes "board-next run: all gates passed; artifacts in $(BOARD_RUNS)/$(TASK)/" --plain > /dev/null
	@echo "board-task: $(TASK) -> Done (artifacts: $(BOARD_RUNS)/$(TASK)/)"
