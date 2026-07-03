import unittest
from tokenizer import tokenize

class TestTokenizer(unittest.TestCase):
    def test_basic_tokenization(self):
        self.assertEqual(tokenize("Hello World"), ["hello", "world"])

    def test_lowercase(self):
        self.assertEqual(tokenize("ABCdef"), ["abcdef"])

    def test_punctuation(self):
        self.assertEqual(tokenize("hello, world! this... is a test."), ["hello", "world", "this", "is", "a", "test"])

    def test_numbers(self):
        self.assertEqual(tokenize("abc123def456ghi"), ["abc", "def", "ghi"])

    def test_whitespace(self):
        self.assertEqual(tokenize("  hello   \t\n  world  "), ["hello", "world"])

    def test_empty_input(self):
        self.assertEqual(tokenize(""), [])
        self.assertEqual(tokenize("   "), [])
        self.assertEqual(tokenize("123!!!###"), [])

    def test_mixed_boundaries(self):
        self.assertEqual(tokenize("!word1?word2_word3"), ["word", "word", "word"])

if __name__ == "__main__":
    unittest.main()
