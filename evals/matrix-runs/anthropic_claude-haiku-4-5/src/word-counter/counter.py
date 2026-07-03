#!/usr/bin/env python3
"""
Core word frequency engine.
Reads stdin, lowercases, splits on [^a-z], counts occurrences.
Returns dict {word: count}.
"""

import sys
import re
import json


def count_words(text):
    """
    Count word frequencies in text.
    
    Args:
        text: Input string
        
    Returns:
        dict: {word: count} where words are lowercased, split on [^a-z]
    """
    # Lowercase
    text = text.lower()
    
    # Split on anything that's not a-z
    words = re.split(r'[^a-z]+', text)
    
    # Filter out empty strings
    words = [w for w in words if w]
    
    # Count occurrences
    counts = {}
    for word in words:
        counts[word] = counts.get(word, 0) + 1
    
    return counts


def main():
    """Read stdin and output word counts as JSON."""
    text = sys.stdin.read()
    counts = count_words(text)
    print(json.dumps(counts, sort_keys=True))


if __name__ == '__main__':
    main()
