import tempfile
import unittest
import shutil
from pathlib import Path
from check_curriculum import ROOT, audit
from lesson_yaml import loads, dumps


class CurriculumAuditTests(unittest.TestCase):
    def test_partial_inventory_is_not_full_acceptance(self):
        errors, states = audit()
        self.assertEqual(errors, [])
        self.assertEqual(sum(states.values()), 128)
        if states['verified'] < 128:
            self.assertTrue(audit(complete=True)[0])

    def test_audit_catches_missing_delivery_and_scope_drift(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shutil.copytree(ROOT / 'Resources/Lessons', root / 'Resources/Lessons')
            shutil.copytree(ROOT / 'docs/curriculum', root / 'docs/curriculum')
            path = root / 'docs/curriculum/coverage.yml'
            original = path.read_text()
            for defect in ['duplicate', 'missing', 'false-completion', 'module']:
                with self.subTest(defect=defect):
                    data = loads(original)
                    if defect == 'duplicate':
                        data['lessons'][1]['lessonID'] = data['lessons'][0]['lessonID']
                    elif defect == 'missing':
                        data['lessons'].pop()
                    elif defect == 'false-completion':
                        data['lessons'][0]['status'] = 'verified'
                        data['lessons'][0].pop('reviewPath', None)
                    else:
                        data['lessons'][0]['moduleID'] = 'first-notes'
                    path.write_text(dumps(data))
                    self.assertTrue(audit(root)[0])
