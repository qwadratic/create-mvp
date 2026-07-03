#!/usr/bin/env python3
import sys
import os

def main():
    try:
        # Resolve sibling imports using relative sys.path additions
        src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        sys.path.insert(0, os.path.join(src_dir, "cli-arguments"))
        sys.path.insert(0, os.path.join(src_dir, "word-tokenization"))
        sys.path.insert(0, os.path.join(src_dir, "frequency-sorting"))
        sys.path.insert(0, os.path.join(src_dir, "json-serialization"))

        from cli_args import parse_args
        from tokenizer import tokenize
        from sorting import count_and_sort
        from serializer import serialize
    except ImportError as e:
        print(f"Error importing components: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        args = parse_args(sys.argv[1:])
    except ValueError as e:
        print(f"Error parsing arguments: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        text = sys.stdin.read()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:
        print(f"Error reading stdin: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        tokens = tokenize(text)
        sorted_items = count_and_sort(tokens, top_n=args.top)
        # ponytail: standard compact=False matches goal representation '[{"word": "...", "count": N}, ...]'
        output = serialize(sorted_items, compact=False)
        print(output)
    except Exception as e:
        print(f"Error processing text: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
