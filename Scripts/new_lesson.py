#!/usr/bin/env python3
"""Create a bilingual lesson draft from the checked-in template; never overwrite a lesson."""
import argparse
import json
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def create(lesson_id: str, catalog_root: Path, policy: str) -> Path:
    # Leave nine characters for the globally unique exercise suffix '-practice'.
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,54}", lesson_id):
        raise ValueError("Use 1–55 lowercase ASCII letters, digits or hyphens, starting with a letter")
    catalog_root = catalog_root.resolve()
    catalog_path = catalog_root / "catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("schemaVersion") != 1 or not isinstance(catalog.get("lessons"), list) or not all(isinstance(x, str) for x in catalog["lessons"]):
        raise ValueError("Expected an existing schema-1 lesson catalog")
    destination = catalog_root / lesson_id
    if destination.exists() or destination.is_symlink() or lesson_id in catalog["lessons"]:
        raise ValueError("Lesson already exists; no files were changed")

    exercise_id = lesson_id + "-practice"
    for existing_id in catalog["lessons"]:
        if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", existing_id):
            raise ValueError("The existing catalog contains an invalid lesson ID")
        manifest = json.loads((catalog_root / existing_id / "lesson.json").read_text(encoding="utf-8"))
        if any(exercise.get("id") == exercise_id for exercise in manifest["exercises"]):
            raise ValueError("Generated exercise ID is already used by another lesson; choose a different lesson ID")

    def rename(value):
        if isinstance(value, str):
            return value.replace("lesson-template", lesson_id)
        if isinstance(value, dict):
            return {key: rename(item) for key, item in value.items()}
        if isinstance(value, list):
            return [rename(item) for item in value]
        return value

    # Prepare the complete folder before registering it in the catalog.
    staged = Path(tempfile.mkdtemp(prefix=".lesson-draft-", dir=catalog_root))
    registered = False
    created = False
    catalog_temp = None
    try:
        for filename in ["lesson.json", "en.json", "uk.json", "adaptive.en.json", "adaptive.uk.json"]:
            source = ROOT / "docs/templates/lesson" / filename
            data = rename(json.loads(source.read_text(encoding="utf-8")))
            if source.name == "lesson.json":
                data["adaptation"]["policy"] = policy
            (staged / source.name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        destination.mkdir()  # Fails if another author created this ID in the meantime.
        created = True
        for source in staged.iterdir():
            source.replace(destination / source.name)
        catalog["lessons"].append(lesson_id)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=catalog_root, prefix=".catalog-", delete=False) as file:
            catalog_temp = Path(file.name)
            json.dump(catalog, file, ensure_ascii=False, indent=2)
            file.write("\n")
        catalog_temp.replace(catalog_path)
        registered = True
    finally:
        shutil.rmtree(staged)
        if created and not registered:
            shutil.rmtree(destination)
        if catalog_temp is not None:
            catalog_temp.unlink(missing_ok=True)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lesson_id", help="Stable ID, at most 55 characters")
    parser.add_argument("--catalog", type=Path, default=ROOT / "Resources/Lessons", help="Existing lesson catalog directory")
    parser.add_argument("--policy", choices=["fretPattern", "transposeIntervals"], default="fretPattern")
    args = parser.parse_args()
    try:
        result = create(args.lesson_id, args.catalog, args.policy)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Cannot create lesson: {error}\n")
    print(f"Created draft: {result}\nEdit both languages and the musical exercise, then run ValidateLessonContent before building.")


if __name__ == "__main__":
    main()
