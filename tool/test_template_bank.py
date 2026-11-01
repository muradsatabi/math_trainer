import copy
import unittest
from template_bank import apply_package, approval_valid, content_digest, digest, records, validate_transition


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.record = {"id":"sample_tpl_001","title":"Sample","family":"numeric",
                       "features":[],"example":"2a+2b → 2(a+b)","status":"active","revision":1}
        self.document = {"schema_version":1,"templates":[self.record]}

    def approved(self, record):
        record = copy.deepcopy(record)
        record["approval"] = {"decision":"approved","approved_by":"owner",
          "approved_at":"2026-11-01T18:00:00Z","source_ref":"methodical-chat/decision",
          "content_sha256":content_digest(record)}
        return record

    def test_revision_and_bound_approval(self):
        record = self.approved({**self.record,"revision":2,"title":"Updated"})
        updated = {**self.document,"templates":[record]}
        validate_transition(self.document,updated)
        record["title"] = "Tampered"
        self.assertFalse(approval_valid(record))
        with self.assertRaises(ValueError): records(updated)

    def test_approved_upsert_is_idempotent_and_stale_base_rejected(self):
        record = self.approved({**self.record,"revision":2,"title":"Updated"})
        package = {"schema_version":1,"base_content_sha256":digest(self.document),"templates":[record]}
        updated = apply_package(self.document,package)
        self.assertEqual(apply_package(updated,package),updated)
        package["templates"][0]["revision"] = 3
        with self.assertRaises(ValueError): apply_package(updated,package)

    def test_no_silent_deletion_or_unapproved_activation(self):
        other = {**self.record,"id":"sample_tpl_002"}
        with self.assertRaises(ValueError): validate_transition(self.document,{**self.document,"templates":[other]})
        with self.assertRaises(ValueError): validate_transition(self.document,
            {**self.document,"templates":[{**self.record,"title":"Changed"}]})
        with self.assertRaises(ValueError): records({**self.document,"templates":[{**self.record,"methodical_status":"review"}]})

    def test_duplicates_unsupported_features_and_broken_parents(self):
        for invalid in [self.document["templates"]*2,
                        [{**self.record,"features":["invented"]}],
                        [{**self.record,"parents":["absent"]}]]:
            with self.assertRaises(ValueError): records({**self.document,"templates":invalid})

    def test_strict_flags_and_cycles_are_rejected(self):
        with self.assertRaises(ValueError): records({**self.document,"templates":[{**self.record,"flat":"false"}]})
        first={**self.record,"parents":["sample_tpl_002"]}
        second={**self.record,"id":"sample_tpl_002","parents":["sample_tpl_001"]}
        with self.assertRaises(ValueError): records({**self.document,"templates":[first,second]})


if __name__ == "__main__":
    unittest.main()
