#!/usr/bin/env bash
# stub-agent: deterministic agent adapter. No network, no LLM.
# CLI: agent.sh plan <goal-file>   -> JSON plan on stdout
#      agent.sh build <id>         -> writes out/<id>/main.sh + marker
set -euo pipefail

cmd="${1:-}"
case "$cmd" in
  plan)
    goal="${2:?usage: agent.sh plan <goal-file>}"
    [ -f "$goal" ] || { echo "agent.sh: goal file not found: $goal" >&2; exit 1; }
    # deterministic plan derived only from goal file name (content ignored on purpose)
    cat <<'JSON'
{"components":[{"id":"core","desc":"core component","deps":[]},{"id":"cli","desc":"cli component","deps":["core"]},{"id":"docs","desc":"docs component","deps":["core","cli"]}]}
JSON
    ;;
  build)
    id="${2:?usage: agent.sh build <id>}"
    case "$id" in
      *[!a-z0-9-]*|"") echo "agent.sh: bad component id: $id" >&2; exit 1 ;;
    esac
    dir="out/$id"
    mkdir -p "$dir"
    cat > "$dir/main.sh" <<EOF
#!/usr/bin/env bash
echo "component $id"
EOF
    chmod +x "$dir/main.sh"
    printf 'built %s\n' "$id" > "$dir/.built"
    ;;
  *)
    echo "usage: agent.sh {plan <goal-file>|build <id>}" >&2
    exit 2
    ;;
esac
