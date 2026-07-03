#!/usr/bin/env python3
"""
Sorts frequencies by count (desc) then word (asc).
Outputs deterministic JSON: [{"word": ..., "count": ...}, ...].
No extra whitespace.
"""

import sys
import json


def format_frequencies(freq_dict):
    """
    Convert frequency dict to sorted list of {word, count} objects.
    
    Args:
        freq_dict: dict {word: count}
        
    Returns:
        list: [{"word": ..., "count": ...}, ...] sorted by count desc, then word asc
    """
    # Convert dict to list of {word, count}
    items = [{"word": word, "count": count} for word, count in freq_dict.items()]
    
    # Sort by count (desc) then word (asc)
    # Use tuple: (-count, word) for proper ordering
    items.sort(key=lambda x: (-x["count"], x["word"]))
    
    return items


def main():
    """Read JSON freq dict from stdin, output sorted JSON array."""
    freq_dict = json.loads(sys.stdin.read())
    result = format_frequencies(freq_dict)
    # Compact JSON: no spaces after separators
    print(json.dumps(result, separators=(',', ':'), ensure_ascii=True))


if __name__ == '__main__':
    main()
