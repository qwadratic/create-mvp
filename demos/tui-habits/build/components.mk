build/habit-store.done: build/plan.json 
	$(AGENT) build habit-store
	bash src/habit-store/check.sh
	touch $@
COMPONENTS += build/habit-store.done

build/streak-logic.done: build/plan.json 
	$(AGENT) build streak-logic
	bash src/streak-logic/check.sh
	touch $@
COMPONENTS += build/streak-logic.done

build/render-view.done: build/plan.json build/habit-store.done build/streak-logic.done
	$(AGENT) build render-view
	bash src/render-view/check.sh
	touch $@
COMPONENTS += build/render-view.done

build/cli-commands.done: build/plan.json build/habit-store.done build/render-view.done
	$(AGENT) build cli-commands
	bash src/cli-commands/check.sh
	touch $@
COMPONENTS += build/cli-commands.done

build/tui-loop.done: build/plan.json build/habit-store.done build/streak-logic.done build/render-view.done
	$(AGENT) build tui-loop
	bash src/tui-loop/check.sh
	touch $@
COMPONENTS += build/tui-loop.done

