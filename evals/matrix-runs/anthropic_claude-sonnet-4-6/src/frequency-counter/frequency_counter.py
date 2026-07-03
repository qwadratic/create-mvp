from collections import Counter

def top_n(words: list[str], n: int) -> list[dict]:
    counts = Counter(words)
    ranked = sorted(counts.items(), key=lambda x: (-x[1], x[0]))
    return [{'word': w, 'count': c} for w, c in ranked[:n]]

if __name__ == '__main__':
    assert top_n(['a', 'b', 'a', 'b', 'c'], 2) == [{'word': 'a', 'count': 2}, {'word': 'b', 'count': 2}]
    assert top_n([], 5) == []
    assert top_n(['x', 'y', 'x'], 1) == [{'word': 'x', 'count': 2}]
    print('ok')
