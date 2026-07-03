import json

def serialize(items: list, compact: bool = True, indent: int = None) -> str:
    """
    Serializes a list of dictionaries containing 'word' and 'count' into a deterministic JSON string.
    Ensures 'word' is placed before 'count' in each serialized object.
    
    ponytail: uses Python 3.7+ dictionary insertion order for key order determinism.
    """
    if not isinstance(items, list):
        raise TypeError("Input must be a list of dictionaries")

    standardized = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            raise TypeError(f"Item at index {idx} is not a dictionary")
        if "word" not in item:
            raise KeyError(f"Item at index {idx} is missing 'word' key")
        if "count" not in item:
            raise KeyError(f"Item at index {idx} is missing 'count' key")

        # Validate types or convert
        try:
            word_str = str(item["word"])
        except Exception as e:
            raise ValueError(f"Could not convert 'word' at index {idx} to string") from e

        try:
            count_val = int(item["count"])
        except (ValueError, TypeError) as e:
            raise ValueError(f"Could not convert 'count' at index {idx} to integer: {item['count']}") from e

        # Explicitly construct dict with 'word' first, then 'count'
        standardized.append({
            "word": word_str,
            "count": count_val
        })

    if indent is not None:
        return json.dumps(standardized, indent=indent)
    
    if compact:
        # Compact JSON without whitespace (e.g. [{"word":"a","count":1}])
        return json.dumps(standardized, separators=(',', ':'))
    else:
        # Standard JSON with spaces (e.g. [{"word": "a", "count": 1}])
        return json.dumps(standardized)
