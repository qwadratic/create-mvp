import argparse
import sys

def parse_args(args):
    """
    Parses command line arguments.
    args: list of string arguments (e.g., sys.argv[1:])
    Returns a namespace with the parsed arguments.
    Raises ValueError for invalid inputs (negative values, non-integers, unknown flags).
    """
    parser = argparse.ArgumentParser(prog="wordfreq", add_help=False)
    parser.add_argument("--top", default=5)
    
    # Since argparse exits on error, we override error handling or catch SystemExit
    class ThrowingArgumentParser(argparse.ArgumentParser):
        def error(self, message):
            raise ValueError(message)

    parser = ThrowingArgumentParser(prog="wordfreq", add_help=False)
    parser.add_argument("--top", default=5)

    try:
        parsed, unknown = parser.parse_known_args(args)
    except Exception as e:
        raise ValueError(f"Argument parsing error: {e}")

    if unknown:
        raise ValueError(f"Unknown arguments: {unknown}")

    # Validate top
    try:
        # If default, it is an int, otherwise it is string from command line
        top_val = int(parsed.top)
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid value for --top: must be an integer, got '{parsed.top}'") from e

    if top_val < 0:
        raise ValueError(f"Invalid value for --top: must be non-negative, got {top_val}")

    parsed.top = top_val
    return parsed
