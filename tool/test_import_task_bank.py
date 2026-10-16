"""Regression checks for repeated imports and content protection."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import import_task_bank as importer


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.source = json.loads(importer.SOURCE.read_text(encoding="utf-8"))

    def test_repeat_import_preserves_bytes_and_conflicts_write_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source_path = root / "source.json"
            source_path.write_text(json.dumps(self.source), encoding="utf-8")
            with patch.object(importer, "ROOT", root), patch.object(importer, "SOURCE", source_path):
                importer.import_bank()
                before = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
                importer.import_bank()
                importer.import_bank(check=True)
                self.assertEqual(before, {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()})
                conflict = root / "bank/blocks/common_factor_01.json"
                conflict.write_text("published content", encoding="utf-8")
                snapshot = {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()}
                with self.assertRaisesRegex(ValueError, "conflict"):
                    importer.import_bank()
                self.assertEqual(snapshot, {p.relative_to(root): p.read_bytes() for p in root.rglob("*") if p.is_file()})

    def test_duplicate_and_unapproved_rows_are_rejected(self):
        duplicate = copy.deepcopy(self.source)
        duplicate["rows"].append(duplicate["rows"][0])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            importer.build_outputs(duplicate)
        unapproved = copy.deepcopy(self.source)
        unapproved["rows"][0][-1] = "Черновик"
        with self.assertRaisesRegex(ValueError, "Unapproved"):
            importer.build_outputs(unapproved)


if __name__ == "__main__":
    unittest.main()
