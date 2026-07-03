import re

def tokenize(text: str) -> list:
    """
    Lowercases input and splits on any non-letter character.
    ponytail: ASCII-only letters. Upgrade path: use `regex` module for \\p{L} if non-ASCII letters are required.
    """
    lowered = text.lower()
    raw_tokens = re.split(r'[^a-z]+', lowered)
    return [t for t in raw_tokens if t]
