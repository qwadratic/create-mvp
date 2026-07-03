import unittest
from cli_args import parse_args

class TestCliArgs(unittest.TestCase):
    def test_default_value(self):
        args = parse_args([])
        self.assertEqual(args.top, 5)

    def test_valid_custom_value(self):
        args = parse_args(["--top", "10"])
        self.assertEqual(args.top, 10)

    def test_zero_value(self):
        args = parse_args(["--top", "0"])
        self.assertEqual(args.top, 0)

    def test_negative_value_raises_value_error(self):
        with self.assertRaises(ValueError):
            parse_args(["--top", "-5"])

    def test_non_integer_value_raises_value_error(self):
        with self.assertRaises(ValueError):
            parse_args(["--top", "abc"])

    def test_unknown_arguments_raises_value_error(self):
        with self.assertRaises(ValueError):
            parse_args(["--unknown"])

        with self.assertRaises(ValueError):
            parse_args(["--top", "5", "extra_positional"])

    def test_missing_value_raises_value_error(self):
        with self.assertRaises(ValueError):
            parse_args(["--top"])

if __name__ == "__main__":
    unittest.main()
