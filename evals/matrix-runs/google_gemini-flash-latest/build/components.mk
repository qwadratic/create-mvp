build/cli-arguments.done: build/plan.json 
	$(AGENT) build cli-arguments
	bash src/cli-arguments/check.sh
	touch $@
COMPONENTS += build/cli-arguments.done

build/word-tokenization.done: build/plan.json 
	$(AGENT) build word-tokenization
	bash src/word-tokenization/check.sh
	touch $@
COMPONENTS += build/word-tokenization.done

build/frequency-sorting.done: build/plan.json 
	$(AGENT) build frequency-sorting
	bash src/frequency-sorting/check.sh
	touch $@
COMPONENTS += build/frequency-sorting.done

build/json-serialization.done: build/plan.json 
	$(AGENT) build json-serialization
	bash src/json-serialization/check.sh
	touch $@
COMPONENTS += build/json-serialization.done

build/cli-integration.done: build/plan.json build/cli-arguments.done build/word-tokenization.done build/frequency-sorting.done build/json-serialization.done
	$(AGENT) build cli-integration
	bash src/cli-integration/check.sh
	touch $@
COMPONENTS += build/cli-integration.done

build/golden-test.done: build/plan.json build/cli-integration.done
	$(AGENT) build golden-test
	bash src/golden-test/check.sh
	touch $@
COMPONENTS += build/golden-test.done

