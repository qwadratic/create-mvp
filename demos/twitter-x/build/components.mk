build/db-seed.done: build/plan.json 
	$(AGENT) build db-seed
	bash src/db-seed/check.sh
	touch $@
COMPONENTS += build/db-seed.done

build/backend-server.done: build/plan.json build/db-seed.done
	$(AGENT) build backend-server
	bash src/backend-server/check.sh
	touch $@
COMPONENTS += build/backend-server.done

build/reverse-proxy.done: build/plan.json 
	$(AGENT) build reverse-proxy
	bash src/reverse-proxy/check.sh
	touch $@
COMPONENTS += build/reverse-proxy.done

build/ui-page.done: build/plan.json 
	$(AGENT) build ui-page
	bash src/ui-page/check.sh
	touch $@
COMPONENTS += build/ui-page.done

build/load-stand.done: build/plan.json build/reverse-proxy.done
	$(AGENT) build load-stand
	bash src/load-stand/check.sh
	touch $@
COMPONENTS += build/load-stand.done

build/run-harness.done: build/plan.json build/db-seed.done build/backend-server.done build/reverse-proxy.done build/ui-page.done build/load-stand.done
	$(AGENT) build run-harness
	bash src/run-harness/check.sh
	touch $@
COMPONENTS += build/run-harness.done

build/visual-eval.done: build/plan.json build/run-harness.done build/ui-page.done
	$(AGENT) build visual-eval
	bash src/visual-eval/check.sh
	touch $@
COMPONENTS += build/visual-eval.done

