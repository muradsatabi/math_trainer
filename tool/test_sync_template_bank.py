import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import sync_template_bank
from template_bank import content_digest
from sync_template_bank import apply_downloads


def document(revision):
    record={"id":"sample_tpl_001","title":f"Revision {revision}","family":"numeric",
            "features":[],"example":"2a+2b → 2(a+b)","status":"active","revision":revision}
    record['approval']={"decision":"approved","approved_by":"owner","source_ref":"chat/decision",
                        "recorded_at":"2026-11-01","content_sha256":content_digest(record)}
    return json.dumps({"schema_version":1,"templates":[record]}).encode()


class SyncTests(unittest.TestCase):
    def test_windows_transport_keeps_tls_and_reads_utf8(self):
        response=subprocess.CompletedProcess([],0,'{"title":"Степени"}')
        with patch.object(sync_template_bank.sys,'platform','win32'), \
             patch.object(sync_template_bank.subprocess,'CREATE_NO_WINDOW',0,create=True), \
             patch.object(sync_template_bank.subprocess,'run',return_value=response) as run:
            self.assertEqual(sync_template_bank.api('commits/main'),{'title':'Степени'})
            command=run.call_args.args[0]
            self.assertIn('Invoke-RestMethod',command[-1])
            self.assertNotIn('SkipCertificateCheck',command[-1])
            self.assertNotIn('shell',run.call_args.kwargs)
            self.assertTrue(run.call_args.kwargs['check'])
            run.side_effect=subprocess.CalledProcessError(1,command)
            with self.assertRaises(subprocess.CalledProcessError):
                sync_template_bank.api('commits/main')

    def test_windows_transport_rejects_injected_path(self):
        with patch.object(sync_template_bank.sys,'platform','win32'), \
             patch.object(sync_template_bank.subprocess,'run') as run:
            with self.assertRaises(ValueError):
                sync_template_bank.api("commits/main'; Write-Output x")
            run.assert_not_called()

    def test_windows_line_endings_are_preserved_and_tracked_correctly(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);path=root/'bank/templates/sample.json';path.parent.mkdir(parents=True)
            first=document(1)+b'\n'
            path.write_bytes(first.replace(b'\n',b'\r\n'))
            self.assertEqual(apply_downloads(root,{'bank/templates/sample.json':first},'one',lambda *_:False),0)
            second=document(2)+b'\n'
            apply_downloads(root,{'bank/templates/sample.json':second},'two',lambda *_:False)
            self.assertEqual(path.read_bytes(),second.replace(b'\n',b'\r\n'))
            # The next publication can replace the watcher's own pending edit.
            third=document(3)+b'\n'
            apply_downloads(root,{'bank/templates/sample.json':third},'three',lambda *_:True)
            self.assertEqual(path.read_bytes(),third.replace(b'\n',b'\r\n'))

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
