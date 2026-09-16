#!/usr/bin/env python3
"""Audit the agreed course inventory; --complete additionally enforces full delivery.

This checks traceability and structure, not teaching quality or hardware performance.
The Swift content validator remains authoritative for musical and localization contracts.
"""
import argparse
from collections import Counter
from pathlib import Path
from lesson_yaml import loads

ROOT = Path(__file__).resolve().parents[1]
STATES = {'todo', 'needs_review', 'authored', 'verified'}


def audit(root: Path = ROOT, complete: bool = False) -> tuple[list[str], Counter]:
    errors = []
    ledger = loads((root / 'docs/curriculum/coverage.yml').read_text())
    catalog_root = root / 'Resources/Lessons'
    catalog = loads((catalog_root / 'catalog.yml').read_text())
    rows, modules = ledger['lessons'], ledger['modules']
    if ledger.get('schemaVersion') != 1 or ledger.get('expectedLessonCount') != 128:
        errors.append('The accepted scope is schema 1, 128 lessons.')
    if len(rows) != 128 or sorted(r['number'] for r in rows) != list(range(1, 129)):
        errors.append('Inventory must contain each lesson number 1–128 exactly once.')
    ids = [r['lessonID'] for r in rows]
    if len(set(ids)) != len(ids):
        errors.append('Duplicate lesson IDs in coverage ledger.')
    module_ids = [m['id'] for m in modules]
    if len(set(module_ids)) != 16 or sorted(m['order'] for m in modules) != list(range(1, 17)):
        errors.append('Expected 16 distinct ordered modules.')
    if catalog.get('modules') != modules:
        errors.append('Runtime and editorial module definitions differ.')
    module_order = {m['id']: m['order'] for m in modules}
    counts = Counter(r['moduleID'] for r in rows)
    if set(counts) != set(module_ids) or any(n != 8 for n in counts.values()):
        errors.append('Each of the 16 modules must retain its eight accepted topics.')
    statuses = Counter(r['status'] for r in rows)
    for row in rows:
        ident = row['lessonID']
        def fail(message):
            errors.append(f'{ident}: {message}')
        if module_order.get(row['moduleID']) != (row['number'] - 1) // 8 + 1:
            fail('Topic moved outside its accepted module.')
        if row['status'] not in STATES:
            fail('Unknown delivery state.')
        if set(row.get('titles', {})) != {'en', 'uk'} or not all(row['titles'].values()) or not row.get('outcomeUK') or not row.get('originalAssessment'):
            fail('Missing bilingual topic, original outcome or assessment scope.')
        if row['status'] == 'todo':
            if ident in catalog['lessons']:
                fail('Bundled lesson still marked todo; explicitly review its coverage.')
        else:
            if ident not in catalog['lessons']:
                fail('Authored lesson is not registered in the runtime catalog.')
                continue
            manifest_file = catalog_root / ident / 'lesson.yml'
            if not manifest_file.is_file():
                fail('Missing lesson manifest.')
                continue
            manifest = loads(manifest_file.read_text())
            placement = manifest.get('curriculum', {})
            if placement.get('moduleID') != row['moduleID'] or placement.get('ordinal') != row['number']:
                fail('Runtime placement differs from coverage ledger.')
            if row['status'] in {'authored', 'verified'}:
                if len(manifest.get('steps', [])) < 3:
                    fail('Needs progressive teaching, practice and reflection steps.')
                if not manifest.get('learningTasks') and not manifest.get('practiceEntries'):
                    fail('Needs an explicit learning task or practice entry.')
                for language in ['en', 'uk']:
                    path = catalog_root / ident / f'{language}.yml'
                    if not path.is_file():
                        fail(f'Missing {language} edition.')
                        continue
                    text = loads(path.read_text())
                    if any(not text.get(k, '').strip() for k in ['title', 'summary', 'goal', 'body']):
                        fail(f'Incomplete {language} teaching.')
        if row['status'] == 'verified':
            evidence = row.get('reviewPath', '')
            if not evidence or not (root / evidence).is_file() or not evidence.startswith('docs/reviews/'):
                fail('Verified delivery needs a checked-in editorial/software review.')
            if 'Р' in row['originalAssessment'] and not row.get('capabilities'):
                fail('Extension topic requires explicit implemented capability evidence.')
        if complete and row['status'] != 'verified':
            fail(f'Full course acceptance is incomplete ({row["status"]}).')
    return errors, statuses


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--complete', action='store_true')
    args = parser.parse_args()
    errors, counts = audit(complete=args.complete)
    print('128-topic course inventory: ' + ', '.join(f'{key}={counts[key]}' for key in sorted(counts)))
    for error in errors:
        print(error)
    if not errors:
        print('Full acceptance passed.' if args.complete else 'Partial inventory checks passed; this is not full-course acceptance.')
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
