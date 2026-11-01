"""Validate canonical templates and prepare idempotent, versioned imports.

No Git writes or methodology approval are performed by this module.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

FAMILIES = {"numeric", "literal", "numeric_bracket", "literal_bracket"}
FEATURES = {"subtraction", "position", "three_terms", "different", "unit",
            "two_letters", "powers", "factor_power", "bracket"}


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def content_digest(record):
    return digest({k: v for k, v in record.items() if k != "approval"})


def approval_valid(record):
    receipt = record.get("approval", {})
    return (receipt.get("decision") == "approved"
            and receipt.get("content_sha256") == content_digest(record)
            and bool(receipt.get("source_ref"))
            and bool(receipt.get("approved_by"))
            and bool(re.fullmatch(r"\d{4}-\d\d-\d\d(?:T.+(?:Z|[+-]\d\d:\d\d))?",
                                  receipt.get("approved_at", receipt.get("recorded_at", "")))))


def records(document):
    if type(document.get("schema_version")) is not int or document["schema_version"] != 1 or not isinstance(document.get("templates"), list):
        raise ValueError("Unsupported template schema")
    if not document["templates"]:
        raise ValueError("Empty template catalog")
    result = {}
    for record in document["templates"]:
        for key in ("id", "title", "family", "example", "status"):
            if not isinstance(record.get(key), str) or not record[key].strip():
                raise ValueError(f"Missing {key}")
        ident = record["id"]
        if not re.fullmatch(r"[a-z][a-z0-9_]{1,119}", ident) or ident in result:
            raise ValueError(f"Invalid/duplicate ID: {ident}")
        if record["family"] not in FAMILIES:
            raise ValueError(f"Unsupported family: {ident}")
        if record["status"] not in {"active", "deferred", "review"}:
            raise ValueError(f"Unsupported status: {ident}")
        if not isinstance(record.get("features"), list) or not all(isinstance(f, str) for f in record["features"]):
            raise ValueError(f"Invalid features: {ident}")
        if len(set(record["features"])) != len(record["features"]):
            raise ValueError(f"Duplicate features: {ident}")
        if "flat" in record and type(record["flat"]) is not bool:
            raise ValueError(f"Invalid flat flag: {ident}")
        if record.get("operation", "factor") not in {"factor", "expand"}:
            raise ValueError(f"Unsupported operation: {ident}")
        if record["status"] == "active":
            if record["family"].endswith("_bracket") != (record.get("operation", "factor") == "expand"):
                raise ValueError(f"Family and operation do not match: {ident}")
            if set(record["features"]) - FEATURES:
                raise ValueError(f"Unsupported active features: {ident}")
            if record.get("methodical_status", "approved") != "approved":
                raise ValueError(f"Active content is not approved: {ident}")
            if record.get("operation", "factor") == "expand" and not record.get("flat"):
                raise ValueError(f"Expansion hierarchy has not been approved: {ident}")
        if record["example"].count("→") != 1 or not all(p.strip() for p in record["example"].split("→")):
            raise ValueError(f"Missing expression or answer: {ident}")
        revision = record.get("revision", 1)
        if type(revision) is not int or revision < 1:
            raise ValueError(f"Invalid revision: {ident}")
        if "approval" in record and not approval_valid(record):
            raise ValueError(f"Approval is not bound to this exact content: {ident}")
        if "source_text" in record and hashlib.sha256(record["source_text"].encode("utf-8")).hexdigest() != record.get("source_sha256"):
            raise ValueError(f"Damaged methodical source: {ident}")
        result[ident] = record
    for record in result.values():
        parents = record.get("parents", [])
        if not isinstance(parents, list) or not all(isinstance(p, str) for p in parents) or len(set(parents)) != len(parents) or any(p not in result or p == record["id"] for p in parents):
            raise ValueError(f"Invalid parent reference: {record['id']}")
    visited, visiting = set(), set()
    def visit(ident):
        if ident in visiting:
            raise ValueError("Cycle in template dependencies")
        if ident not in visited:
            visiting.add(ident)
            for parent in result[ident].get("parents", []):
                visit(parent)
            visiting.remove(ident)
            visited.add(ident)
    for ident in result:
        visit(ident)
    return result


def validate_transition(previous, current):
    before, after = records(previous), records(current)
    if set(before) - set(after):
        raise ValueError("Previously published template IDs cannot disappear")
    for ident, record in after.items():
        old = before.get(ident)
        if old == record:
            continue
        if old and record.get("revision", 1) <= old.get("revision", 1):
            raise ValueError(f"Changed content needs a new revision: {ident}")
        if record["status"] == "active" and not approval_valid(record):
            raise ValueError(f"Publication needs an explicit content-bound approval: {ident}")


def apply_package(existing, package):
    """Upsert a whole approved block. A retry is a no-op, never a duplicate."""
    if package.get("schema_version") != 1:
        raise ValueError("Unsupported package")
    incoming = package.get("templates")
    if not isinstance(incoming, list) or not incoming:
        raise ValueError("Empty import")
    old = records(existing)
    ids = [r.get("id") for r in incoming]
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate ID in import")
    if all(old.get(r.get("id")) == r for r in incoming):
        return existing
    if package.get("base_content_sha256") != digest(existing):
        raise ValueError("Import base changed; reread the canonical topic")
    merged = dict(old)
    merged.update({r["id"]: r for r in incoming})
    updated = {**existing, "templates": list(merged.values())}
    validate_transition(existing, updated)
    return updated


def validate_repository(root, base_ref=None):
    root = Path(root).resolve()
    if base_ref and (base_ref.startswith("-") or not re.fullmatch(r"[A-Za-z0-9_./-]+", base_ref)):
        raise ValueError("Invalid base ref")
    files = sorted((root / "bank/templates").glob("*.json"))
    seen = set()
    for file in files:
        document = json.loads(file.read_text(encoding="utf-8-sig"))
        current = records(document)
        if seen & current.keys():
            raise ValueError("Template IDs duplicated across topic files")
        seen.update(current)
        if base_ref:
            relative = file.relative_to(root).as_posix()
            result = subprocess.run(["git", "show", f"{base_ref}:{relative}"], cwd=root,
                                    capture_output=True, text=True, encoding="utf-8")
            if result.returncode == 0:
                validate_transition(json.loads(result.stdout), document)
            elif not all(r["status"] != "active" or approval_valid(r) for r in current.values()):
                raise ValueError(f"New topic needs content-bound approvals: {relative}")
    if not files:
        raise ValueError("No template catalogs")
    if base_ref:
        previous = subprocess.run(["git", "ls-tree", "-r", "--name-only", base_ref, "bank/templates"],
                                  cwd=root, capture_output=True, text=True, encoding="utf-8", check=True)
        current_paths = {p.relative_to(root).as_posix() for p in files}
        if {p for p in previous.stdout.splitlines() if p.endswith(".json")} - current_paths:
            raise ValueError("Published topic files cannot disappear")
    return len(files), len(seen)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--base-ref")
    parser.add_argument("--import-package")
    parser.add_argument("--target")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    if args.import_package:
        if not args.target or not re.fullmatch(r"[a-z][a-z0-9_]*\.json", args.target):
            raise ValueError("Target must be a plain catalog filename")
        target = root / "bank/templates" / args.target
        existing = json.loads(target.read_text(encoding="utf-8-sig"))
        package = json.loads(Path(args.import_package).read_text(encoding="utf-8-sig"))
        updated = apply_package(existing, package)
        if updated != existing:
            target.write_text(json.dumps(updated, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    count, templates = validate_repository(root, args.base_ref)
    print(f"Validated {count} catalogs and {templates} unique templates")


if __name__ == "__main__":
    main()
