Decompose this goal into ${FANOUT} buildable components.

GOAL:
${GOAL_TEXT}

Output ONLY raw JSON, no markdown fences, schema:
{"components":[{"id":"kebab-case","desc":"what to build, concrete","deps":["ids of components this needs"],"kind":"leaf|composite (optional, default leaf)","sub_goal":"required iff composite: full goal spec for the subtree"}]}
Rules: ids lowercase kebab-case only (charset [a-z0-9-], gate-enforced); deps may only reference other listed ids; honor tech constraints stated in the goal; each leaf independently checkable via a non-interactive self-test; desc stays mandatory and buildable even for composites (it is the depth-cap fallback and the integration contract siblings read). ${COMPOSITE_RULES}
