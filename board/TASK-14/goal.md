# Build agentmake with agentmake
Self-host: build the agentmake engine, with the agentmake engine, in this run dir. Everything below is self-contained - no repo exploration needed, build exactly this:

1. engine core makefile: goal.md -> plan.json -> jq-generated components.mk (make re-include restart) -> one build step per component, dep-ordered, parallel-safe under make -j, .DELETE_ON_ERROR resume semantics
2. plan gate: jq schema check - components non-empty, kebab-case ids, deps may only reference listed ids
3. stub agent: deterministic bash script with the same CLI contract as a real agent adapter (plan <goal> emits a JSON plan; build <id> writes the component files), so the produced engine is testable offline with zero LLM calls
4. progress census target: filesystem census of expected artifacts, done/total count, non-zero exit only on census error
5. mermaid graph target: parse the rule files back into graph TD edges

Constraints: GNU make + bash + jq + coreutils only; no network; no LLM calls inside any check. Gate: an end-to-end check must run the produced engine on a trivial example goal using the stub agent - plan gate passes, components build in dependency order, census reports all done.

