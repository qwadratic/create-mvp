#!/usr/bin/env python3
"""
wordfreq: CLI interface for word-frequency analysis.
Parses --top N (default 5), reads stdin, pipes through word-counter and json-formatter.
Output: JSON array [{"word": "...", "count": N}, ...] sorted by count desc, word asc.
"""

import sys
import subprocess
import json
import argparse
import os


def main():
    # Parse CLI args
    parser = argparse.ArgumentParser(
        description='Analyze word frequency from stdin',
        add_help=True
    )
    parser.add_argument(
        '--top',
        type=int,
        default=5,
        help='Number of top results to return (default: 5)'
    )
    args = parser.parse_args()
    
    # Locate component scripts
    script_dir = os.path.dirname(os.path.abspath(__file__))
    src_dir = os.path.dirname(script_dir)
    counter_py = os.path.join(src_dir, 'word-counter', 'counter.py')
    formatter_py = os.path.join(src_dir, 'json-formatter', 'formatter.py')
    
    # Read stdin
    stdin_data = sys.stdin.read()
    
    # Pipe through word-counter
    try:
        counter_proc = subprocess.run(
            ['python3', counter_py],
            input=stdin_data,
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"Error in word-counter: {e.stderr}\n")
        sys.exit(1)
    except FileNotFoundError:
        sys.stderr.write(f"Error: word-counter script not found at {counter_py}\n")
        sys.exit(1)
    
    # Pipe through json-formatter
    try:
        formatter_proc = subprocess.run(
            ['python3', formatter_py],
            input=counter_proc.stdout,
            capture_output=True,
            text=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"Error in json-formatter: {e.stderr}\n")
        sys.exit(1)
    except FileNotFoundError:
        sys.stderr.write(f"Error: json-formatter script not found at {formatter_py}\n")
        sys.exit(1)
    
    # Parse formatted result and slice top-N
    result = json.loads(formatter_proc.stdout)
    top_n = result[:args.top]
    
    # Output compact deterministic JSON
    print(json.dumps(top_n, separators=(',', ':'), ensure_ascii=True))


if __name__ == '__main__':
    main()
