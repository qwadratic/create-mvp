from collections import Counter

def count_and_sort(tokens: list[str], top_n: int = 5) -> list[dict]:
    """
    Counts frequency of each word, sorts by count descending,
    then by word ascending for ties, and slices to top_n.

    ponytail: Uses Python's built-in collections.Counter and sorted().
    Complexity is O(U log U) where U is unique words.
    For extremely large datasets, we can use a min-heap or quickselect for O(U log top_n).
    """
    if not isinstance(top_n, int):
        raise TypeError("top_n must be an integer")
    if top_n < 0:
        raise ValueError("top_n must be non-negative")

    # Count frequencies
    counts = Counter(tokens)

    # Sort: count descending (-count), then word ascending (word)
    sorted_items = sorted(counts.items(), key=lambda x: (-x[1], x[0]))

    # Slice to top_n
    sliced = sorted_items[:top_n]

    # Format as list of dicts
    return [{"word": word, "count": count} for word, count in sliced]
