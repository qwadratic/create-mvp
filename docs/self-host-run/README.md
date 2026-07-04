# Self-host run — task-14, "Build agentmake with agentmake"

Run artifacts committed as they landed (`goal.md`, `Makefile`, `src/`). This
is the blow-by-blow the README summarizes.

## The run

`make board-next` pulled task-14; the engine decomposed it into 7 components
— stub agent, plan gate, components generator, engine core makefile, census,
mermaid graph, e2e check — built dep-ordered under `-j2`, passed full review.
The produced engine runs a goal end-to-end with a deterministic stub agent,
no LLM in the checks.
[wfcheck](../../evals/wfcheck): 32/32, score 1.0.

## It took three runs

The first two died at the plan gate: the planner hallucinated tool calls
instead of JSON (tool-less planners can roleplay — the
[limitations list](../../README.md#honest-limitations) carries this).
`.DELETE_ON_ERROR` cleaned up the garbage plan, the task stayed In Progress
on the board, rerunning resumed at the failed gate — the jq gate rejected it
twice; retries are paid. The fix and the follow-up hardening task (task-15)
are on the board.
