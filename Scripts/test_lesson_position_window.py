import tempfile
import unittest
from pathlib import Path
from lesson_yaml import loads
from new_lesson import create

class PositionWindowTests(unittest.TestCase):
    def test_two_hand_search_window_is_preserved_and_invalid_width_changes_nothing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.yml'
            catalog.write_text('schemaVersion: 1\nlessons: []\n')
            for width in [8, 12, 13]:
                output = create(f'wide-{width}', root, 'transposeIntervals', window=width, starts='5,7')
                lesson = loads((output / 'lesson.yml').read_text())
                self.assertEqual(lesson['materials'][0]['positioning']['windowFrets'], width)
            before = catalog.read_bytes()
            for width in [0, 14]:
                with self.assertRaises(ValueError):
                    create('invalid', root, 'transposeIntervals', window=width)
                self.assertFalse((root / 'invalid').exists())
                self.assertEqual(catalog.read_bytes(), before)
