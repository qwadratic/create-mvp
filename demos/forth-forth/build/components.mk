build/tests-golden.done: build/plan.json 
	$(AGENT) build tests-golden
	bash src/tests-golden/check.sh
	touch $@
COMPONENTS += build/tests-golden.done

build/stage0-core.done: build/plan.json 
	$(AGENT) build stage0-core
	bash src/stage0-core/check.sh
	touch $@
COMPONENTS += build/stage0-core.done

build/stage0-compiler-support.done: build/plan.json build/stage0-core.done
	$(AGENT) build stage0-compiler-support
	bash src/stage0-compiler-support/check.sh
	touch $@
COMPONENTS += build/stage0-compiler-support.done

build/stage0-gate.done: build/plan.json build/stage0-core.done build/tests-golden.done
	$(AGENT) build stage0-gate
	bash src/stage0-gate/check.sh
	touch $@
COMPONENTS += build/stage0-gate.done

build/stage1-compiler.done: build/plan.json build/stage0-core.done build/stage0-compiler-support.done
	$(AGENT) build stage1-compiler
	bash src/stage1-compiler/check.sh
	touch $@
COMPONENTS += build/stage1-compiler.done

build/gate.done: build/plan.json build/stage0-gate.done build/stage1-compiler.done build/tests-golden.done
	$(AGENT) build gate
	bash src/gate/check.sh
	touch $@
COMPONENTS += build/gate.done

build/selfhost.done: build/plan.json build/stage1-compiler.done build/gate.done
	$(AGENT) build selfhost
	bash src/selfhost/check.sh
	touch $@
COMPONENTS += build/selfhost.done

