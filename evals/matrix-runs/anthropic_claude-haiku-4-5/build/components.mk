build/word-counter.done: build/plan.json 
	$(AGENT) build word-counter
	bash src/word-counter/check.sh
	touch $@
COMPONENTS += build/word-counter.done

build/json-formatter.done: build/plan.json build/word-counter.done
	$(AGENT) build json-formatter
	bash src/json-formatter/check.sh
	touch $@
COMPONENTS += build/json-formatter.done

build/cli-interface.done: build/plan.json build/word-counter.done build/json-formatter.done
	$(AGENT) build cli-interface
	bash src/cli-interface/check.sh
	touch $@
COMPONENTS += build/cli-interface.done

build/golden-test.done: build/plan.json build/cli-interface.done
	$(AGENT) build golden-test
	bash src/golden-test/check.sh
	touch $@
COMPONENTS += build/golden-test.done

