Decompose this goal into ${FANOUT} buildable components.

GOAL:
${GOAL_TEXT}

Output ONLY raw JSON, no markdown fences, schema:
{"components":[{"id":"kebab-case","desc":"what to build, concrete","deps":["ids of components this needs"]}]}
Rules: deps may only reference other listed ids; honor tech constraints stated in the goal; each component independently checkable via a non-interactive self-test.
