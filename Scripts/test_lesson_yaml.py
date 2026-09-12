"""Author YAML regression checks; run with python3 -m unittest discover -s Scripts."""
import unittest
from lesson_yaml import loads, dumps


class LessonYAMLTests(unittest.TestCase):
    def test_round_trip_preserves_text_types_and_paragraphs(self):
        value = {"body": "Перший абзац: C♯4 # нота.\n\nДругий абзац.", "enabled": True,
                 "frets": [0, 7, 24], "none": None, "tokens": "{{notes}}", "words": ["yes", "null", "1"],
                 "long": ("Play slowly and listen carefully. " * 10).rstrip(), "trailing": "keep this space "}
        encoded = dumps(value)
        self.assertIn("|-", encoded)
        self.assertIn(">-", encoded)
        self.assertEqual(loads(encoded), value)

    def test_rejects_duplicate_keys_multiple_documents_and_unsafe_tags(self):
        for text in ["id: one\nid: two", "source:\n  kind: lesson\n  kind: exercise",
                     "id: one\n---\nid: two", "!!python/object:os.system {}", "notes: [unfinished"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                loads(text)


if __name__ == "__main__":
    unittest.main()
