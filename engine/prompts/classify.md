Classify how much effort the user put into this goal spec. Agent effort must be proportional to user effort.

GOAL:
${GOAL_TEXT}

Rubric:
- vague: one-liner, no constraints, no acceptance criteria ("make me a todo app")
- standard: some specifics — named features, tech constraints, or rough structure
- prd: acceptance criteria, structured sections, edge cases spelled out

Tier → knobs (use EXACTLY this mapping):
- vague:    {"fanout":"2-3","review_depth":"smoke","model_hint":"small","thinking":"low"}
- standard: {"fanout":"3-5","review_depth":"standard","model_hint":"default","thinking":"medium"}
- prd:      {"fanout":"5-8","review_depth":"full","model_hint":"large","thinking":"high"}

Output ONLY raw JSON, no markdown fences, single line:
{"tier":"vague|standard|prd","fanout":"N-M","review_depth":"smoke|standard|full","model_hint":"small|default|large","thinking":"off|low|medium|high"}
