"""Import the owner's exact source snapshot; never overwrite changed content."""
import argparse
import hashlib
import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "bank/sources/common_factor_v8.json"
# Owner-requested short window for checking application features.
PRACTICE_WINDOW = 10


def encode(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def build_outputs(source):
    columns = source["columns"]
    expected_columns = ["topic_id", "section_id", "task_id", "Блок", "Навык",
                        "Условие", "Выражение", "Ожидаемый ответ", "Допустимые ответы", "Статус"]
    if columns != expected_columns:
        raise ValueError("Unexpected source columns")
    records = []
    seen = set()
    groups = OrderedDict()
    for row in source["rows"]:
        if len(row) != len(columns) or any(not isinstance(v, str) or not v.strip() for v in row):
            raise ValueError("Incomplete source row")
        item = dict(zip(columns, row))
        if item["task_id"] in seen:
            raise ValueError(f"Duplicate task ID: {item['task_id']}")
        if item["Статус"] != "Согласовано":
            raise ValueError(f"Unapproved task: {item['task_id']}")
        seen.add(item["task_id"])
        groups.setdefault(item["Блок"], []).append(item)
        records.append(item)
    if not records or len({r["topic_id"] for r in records}) != 1:
        raise ValueError("Expected exactly one nonempty topic")
    outputs = {}
    blocks = []
    for title, items in groups.items():
        number = int(title.split(" — ", 1)[0])
        block_id = f"common_factor_{number:02d}"
        if len({i["Навык"] for i in items}) != 1 or len({i["section_id"] for i in items}) != 1:
            raise ValueError(f"Mixed source skills/sections in {title}")
        skill_id = block_id
        outputs[f"bank/skills/{skill_id}.json"] = encode({
            "schema_version": 1, "micro_skill_id": skill_id, "revision": 1,
            "title": items[0]["Навык"], "topic_id": items[0]["topic_id"],
            "answer_policy": {
                "requires_mathematical_equivalence": True,
                "required_action": "factor_out_common_factor",
                "answer_examples_are_exhaustive": False,
                "requires_greatest_factor": False,
                "checker_status": "partial_source_examples",
                "notes": source["notes"],
            },
        })
        path = f"bank/blocks/{block_id}.json"
        blocks.append(path)
        outputs[path] = encode({
            "schema_version": 1, "block_id": block_id, "title": title,
            "skill": items[0]["Навык"],
            "micro_skill_ref": {"id": skill_id, "revision": 1},
            "source_section_id": items[0]["section_id"],
            "source": source["source"],
            "tasks": [{
                "task_id": i["task_id"], "revision": 1,
                "instruction": i["Условие"], "expression": i["Выражение"],
                "expected_answer": i["Ожидаемый ответ"],
                "accepted_examples": [i["Допустимые ответы"]],
                "methodical_status": "approved",
            } for i in items],
        })
    outputs["bank/manifest.json"] = encode({
        "schema_version": 1, "topic_id": records[0]["topic_id"],
        "title": "Вынесение общего множителя за скобки",
        "blocks": blocks,
        "practice": {"minimum_answers": PRACTICE_WINDOW, "success_window": PRACTICE_WINDOW,
                     "pass_percent": 85, "extra_tasks_per_error": 2},
        "source_snapshot": "bank/sources/common_factor_v8.json",
        "source_snapshot_sha256": hashlib.sha256(encode(source).encode("utf-8")).hexdigest(),
        "publication_status": "local_unpublished",
    })
    return outputs


def import_bank(check=False):
    source = json.loads(SOURCE.read_text(encoding="utf-8-sig"))
    outputs = build_outputs(source)
    # Preflight the entire import before writing any file. Conflicts are errors.
    for relative, expected in outputs.items():
        path = ROOT / relative
        if path.exists() and path.read_text(encoding="utf-8") != expected:
            raise ValueError(f"Content conflict, not overwritten: {relative}")
        if check and not path.exists():
            raise ValueError(f"Missing generated file: {relative}")
    if not check:
        for relative, expected in outputs.items():
            path = ROOT / relative
            if not path.exists():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(expected, encoding="utf-8", newline="\n")
    print(f"{'Verified' if check else 'Imported'} {len(source['rows'])} tasks, "
          f"{len(outputs) // 2} blocks; no conflicting content overwritten")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    import_bank(check=args.check)
