build/stub-agent.done: build/plan.json 
	$(AGENT) build stub-agent
	bash src/stub-agent/check.sh
	touch $@
COMPONENTS += build/stub-agent.done

build/plan-gate.done: build/plan.json 
	$(AGENT) build plan-gate
	bash src/plan-gate/check.sh
	touch $@
COMPONENTS += build/plan-gate.done

build/components-generator.done: build/plan.json build/plan-gate.done
	$(AGENT) build components-generator
	bash src/components-generator/check.sh
	touch $@
COMPONENTS += build/components-generator.done

build/engine-core-makefile.done: build/plan.json build/stub-agent.done build/plan-gate.done build/components-generator.done
	$(AGENT) build engine-core-makefile
	bash src/engine-core-makefile/check.sh
	touch $@
COMPONENTS += build/engine-core-makefile.done

build/census-target.done: build/plan.json build/engine-core-makefile.done
	$(AGENT) build census-target
	bash src/census-target/check.sh
	touch $@
COMPONENTS += build/census-target.done

build/mermaid-target.done: build/plan.json build/components-generator.done
	$(AGENT) build mermaid-target
	bash src/mermaid-target/check.sh
	touch $@
COMPONENTS += build/mermaid-target.done

build/e2e-check.done: build/plan.json build/engine-core-makefile.done build/census-target.done build/mermaid-target.done build/stub-agent.done
	$(AGENT) build e2e-check
	bash src/e2e-check/check.sh
	touch $@
COMPONENTS += build/e2e-check.done

