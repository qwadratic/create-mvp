#!/usr/bin/env python3
import argparse
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'word-tokenizer'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'frequency-counter'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'json-serializer'))

from tokenizer import tokenize
from frequency_counter import top_n
from json_serializer import serialize

def main():
    parser = argparse.ArgumentParser(description='Word frequency counter')
    parser.add_argument('--top', type=int, default=5, metavar='N',
                        help='Number of top words to output (default: 5)')
    args = parser.parse_args()

    text = sys.stdin.read()
    words = tokenize(text)
    ranked = top_n(words, args.top)
    print(serialize(ranked))

if __name__ == '__main__':
    main()
