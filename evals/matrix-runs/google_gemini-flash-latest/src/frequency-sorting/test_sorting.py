import unittest
from sorting import count_and_sort

class TestFrequencySorting(unittest.TestCase):
    def test_empty_input(self):
        self.assertEqual(count_and_sort([]), [])
        self.assertEqual(count_and_sort([], top_n=10), [])

    def test_basic_sorting(self):
        tokens = ["apple", "banana", "apple", "cherry", "banana", "apple"]
        # apple: 3, banana: 2, cherry: 1
        expected = [
            {"word": "apple", "count": 3},
            {"word": "banana", "count": 2},
            {"word": "cherry", "count": 1}
        ]
        self.assertEqual(count_and_sort(tokens), expected)

    def test_tie_breaking(self):
        # All have frequency 2
        # Alphabetical: apple, banana, cherry
        tokens = ["cherry", "banana", "apple", "cherry", "banana", "apple"]
        expected = [
            {"word": "apple", "count": 2},
            {"word": "banana", "count": 2},
            {"word": "cherry", "count": 2}
        ]
        self.assertEqual(count_and_sort(tokens), expected)

    def test_duplicate_counts_with_mixed_frequencies(self):
        # apple: 3, banana: 2, cherry: 2, date: 1, elderberry: 1
        # Expecting: apple (3), banana (2, tie), cherry (2, tie), date (1, tie), elderberry (1, tie)
        tokens = [
            "banana", "cherry", "apple", "banana", "cherry", "apple", "apple",
            "date", "elderberry"
        ]
        expected_top_5 = [
            {"word": "apple", "count": 3},
            {"word": "banana", "count": 2},
            {"word": "cherry", "count": 2},
            {"word": "date", "count": 1},
            {"word": "elderberry", "count": 1}
        ]
        self.assertEqual(count_and_sort(tokens, top_n=5), expected_top_5)

        # If top_n is 3, should cut off cherry and date/elderberry
        expected_top_3 = [
            {"word": "apple", "count": 3},
            {"word": "banana", "count": 2},
            {"word": "cherry", "count": 2}
        ]
        self.assertEqual(count_and_sort(tokens, top_n=3), expected_top_3)

        # If top_n is 2, should cut off cherry
        expected_top_2 = [
            {"word": "apple", "count": 3},
            {"word": "banana", "count": 2}
        ]
        self.assertEqual(count_and_sort(tokens, top_n=2), expected_top_2)

    def test_top_n_zero(self):
        tokens = ["apple", "banana"]
        self.assertEqual(count_and_sort(tokens, top_n=0), [])

    def test_top_n_larger_than_unique_words(self):
        tokens = ["apple", "banana"]
        expected = [
            {"word": "apple", "count": 1},
            {"word": "banana", "count": 1}
        ]
        self.assertEqual(count_and_sort(tokens, top_n=100), expected)

    def test_invalid_top_n(self):
        with self.assertRaises(ValueError):
            count_and_sort(["apple"], top_n=-1)
        with self.assertRaises(TypeError):
            count_and_sort(["apple"], top_n="3")

if __name__ == "__main__":
    unittest.main()
