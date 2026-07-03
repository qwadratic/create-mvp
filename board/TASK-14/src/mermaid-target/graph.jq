# plan.json -> mermaid graph TD (run with jq -r -f)
# edges 'dep --> id'; components with no deps listed as bare nodes.
"graph TD",
(.components[] | .id as $i |
  if ((.deps // []) | length) == 0
  then "  \($i)"
  else (.deps[] | "  \(.) --> \($i)")
  end)
