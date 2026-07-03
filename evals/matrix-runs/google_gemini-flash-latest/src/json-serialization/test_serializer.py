import unittest
from serializer import serialize

class TestSerializer(unittest.TestCase):
    def test_basic_compact_serialization(self):
        data = [
            {"word": "hello", "count": 5},
            {"word": "world", "count": 3}
        ]
        expected = '[{"word":"hello","count":5},{"word":"world","count":3}]'
        self.assertEqual(serialize(data, compact=True), expected)

    def test_basic_spaced_serialization(self):
        data = [
            {"word": "hello", "count": 5}
        ]
        expected = '[{"word": "hello", "count": 5}]'
        self.assertEqual(serialize(data, compact=False), expected)

    def test_key_ordering_determinism(self):
        # Even if the keys are provided in reverse order, serialize must be deterministic with "word" first.
        data_reverse = [
            {"count": 10, "word": "apple"}
        ]
        expected = '[{"word":"apple","count":10}]'
        self.assertEqual(serialize(data_reverse, compact=True), expected)

    def test_type_conversions(self):
        # count is string representing int, word is an integer (should be converted to string)
        data = [
            {"word": 123, "count": "456"}
        ]
        expected = '[{"word":"123","count":456}]'
        self.assertEqual(serialize(data, compact=True), expected)

    def test_invalid_inputs(self):
        # Input not a list
        with self.assertRaises(TypeError):
            serialize("not a list")
            
        # Item not a dict
        with self.assertRaises(TypeError):
            serialize([["not", "a", "dict"]])

        # Missing word key
        with self.assertRaises(KeyError):
            serialize([{"count": 5}])

        # Missing count key
        with self.assertRaises(KeyError):
            serialize([{"word": "hello"}])

        # Invalid count value
        with self.assertRaises(ValueError):
            serialize([{"word": "hello", "count": "abc"}])

    def test_escaping_special_chars(self):
        data = [
            {"word": 'hello "world"', "count": 1}
        ]
        expected = '[{"word":"hello \\"world\\"","count":1}]'
        self.assertEqual(serialize(data, compact=True), expected)

    def test_empty_list(self):
        self.assertEqual(serialize([]), '[]')
        self.assertEqual(serialize([], compact=False), '[]')

    def test_unicode_characters(self):
        data = [
            {"word": "café", "count": 42}
        ]
        self.assertEqual(serialize(data, compact=True), '[{"word":"caf\\u00e9","count":42}]')



if __name__ == "__main__":
    unittest.main()
