{ports: [.backends[].port], backends: (.backends|length), total_is_sum: (.total == ([.backends[].requests]|add)), all_nonzero: (all(.backends[]; .requests > 0))}
