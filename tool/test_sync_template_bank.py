import json
from pathlib import Path
import tempfile
import unittest
from template_bank import content_digest
from sync_template_bank import apply_downloads


def document(revision):
    record={"id":"sample_tpl_001","title":f"Revision {revision}","family":"numeric",
            "features":[],"example":"2a+2b → 2(a+b)","status":"active","revision":revision}
    record['approval']={"decision":"approved","approved_by":"owner","source_ref":"chat/decision",
                        "recorded_at":"2026-11-01","content_sha256":content_digest(record)}
    return json.dumps({"schema_version":1,"templates":[record]}).encode()


class SyncTests(unittest.TestCase):
    def test_local_edits_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);path=root/'bank/templates/sample.json';path.parent.mkdir(parents=True)
            path.write_bytes(document(1))
            with self.assertRaisesRegex(ValueError,'Local edits'):
                apply_downloads(root,{'bank/templates/sample.json':document(2)},'published',lambda *_:True)
            self.assertEqual(path.read_bytes(),document(1))

    def test_watcher_updates_can_advance_but_user_edit_is_protected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            apply_downloads(root,{'bank/templates/sample.json':document(1)},'one',lambda *_:False)
            apply_downloads(root,{'bank/templates/sample.json':document(2)},'two',lambda *_:True)
            path=root/'bank/templates/sample.json';path.write_bytes(document(3))
            with self.assertRaises(ValueError):
                apply_downloads(root,{'bank/templates/sample.json':document(4)},'four',lambda *_:True)
            self.assertEqual(path.read_bytes(),document(3))

    def test_remote_deletion_downgrade_or_path_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            apply_downloads(root,{'bank/templates/sample.json':document(2)},'two',lambda *_:False)
            for files in [{}, {'bank/templates/sample.json':document(1)}, {'../outside.json':document(3)}]:
                with self.assertRaises(ValueError): apply_downloads(root,files,'bad',lambda *_:False)
            self.assertEqual((root/'bank/templates/sample.json').read_bytes(),document(2))


if __name__=='__main__':
    unittest.main()
