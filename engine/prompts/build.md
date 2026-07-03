Implement component '${ID}': ${DESC}

Part of larger goal:
${GOAL_TEXT}

Full decomposition (integration contracts): read ${B}/plan.json.
Already-built sibling components (readable for integration): ${SIBLINGS}

Rules:
- write ALL files under ${SRC}/${ID}/
- honor tech constraints stated in the goal; no network installs unless the goal explicitly allows them
- MUST create executable ${SRC}/${ID}/check.sh: non-interactive self-test, exits 0 on success,
  starts/stops any servers it needs itself, finishes under 60s
- keep it MVP-minimal
