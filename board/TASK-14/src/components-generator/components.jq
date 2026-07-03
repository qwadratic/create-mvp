# plan.json -> components.mk (run with jq -r -f)
"# generated from plan.json - do not edit",
"COMPONENTS := \(.components | map(.id) | join(" "))",
"STAMPS := $(COMPONENTS:%=build/%.done)",
"",
(.components[] |
  "build/\(.id).done:\((.deps // []) | map(" build/\(.).done") | join(""))\n\t@mkdir -p build\n\t$(AGENT) build \(.id)\n\t@touch $@\n")
