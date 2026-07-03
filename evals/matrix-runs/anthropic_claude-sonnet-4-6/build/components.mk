build/word-tokenizer.done: build/plan.json 
	$(AGENT) build word-tokenizer
	bash src/word-tokenizer/check.sh
	touch $@
COMPONENTS += build/word-tokenizer.done

build/frequency-counter.done: build/plan.json build/word-tokenizer.done
	$(AGENT) build frequency-counter
	bash src/frequency-counter/check.sh
	touch $@
COMPONENTS += build/frequency-counter.done

build/json-serializer.done: build/plan.json 
	$(AGENT) build json-serializer
	bash src/json-serializer/check.sh
	touch $@
COMPONENTS += build/json-serializer.done

build/cli-entrypoint.done: build/plan.json build/word-tokenizer.done build/frequency-counter.done build/json-serializer.done
	$(AGENT) build cli-entrypoint
	bash src/cli-entrypoint/check.sh
	touch $@
COMPONENTS += build/cli-entrypoint.done

build/golden-input-fixture.done: build/plan.json 
	$(AGENT) build golden-input-fixture
	bash src/golden-input-fixture/check.sh
	touch $@
COMPONENTS += build/golden-input-fixture.done

build/golden-output-fixture.done: build/plan.json build/golden-input-fixture.done build/cli-entrypoint.done
	$(AGENT) build golden-output-fixture
	bash src/golden-output-fixture/check.sh
	touch $@
COMPONENTS += build/golden-output-fixture.done

build/golden-test-runner.done: build/plan.json build/cli-entrypoint.done build/golden-input-fixture.done build/golden-output-fixture.done
	$(AGENT) build golden-test-runner
	bash src/golden-test-runner/check.sh
	touch $@
COMPONENTS += build/golden-test-runner.done

