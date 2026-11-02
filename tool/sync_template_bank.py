"""Pull only published template data; never overwrite unrelated/local edits."""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.request

from template_bank import approval_valid, records, validate_transition

REPOSITORY = "muradsatabi/math_trainer"
PATH = re.compile(r"bank/templates/[a-z][a-z0-9_]*\.json")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def locally_changed(root, relative):
    result = subprocess.run(["git", "status", "--porcelain", "--", relative],
                            cwd=root, text=True, capture_output=True, check=True)
    return bool(result.stdout.strip())


def apply_downloads(root, downloads, commit, dirty_check=locally_changed):
    root = Path(root).resolve()
    directory = (root / "bank/templates").resolve()
    if not directory.is_relative_to(root):
        raise ValueError("Template directory outside workspace")
    if not downloads or any(not PATH.fullmatch(p) for p in downloads):
        raise ValueError("Unexpected or absent catalog paths")
    existing = {p.relative_to(root).as_posix() for p in directory.glob("*.json")}
    if existing - downloads.keys():
        raise ValueError("Remote publication would remove local catalogs")
    state_path = root / ".dart_tool/template-sync.json"
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    applied = state.get("files", {})
    updates = {}
    file_states = {}
    all_ids = set()
    for relative, data in downloads.items():
        target = (root / relative).resolve()
        if not target.is_relative_to(directory):
            raise ValueError("Template target outside bank")
        current = json.loads(data.decode("utf-8-sig"))
        ids = records(current)
        if all_ids & ids.keys():
            raise ValueError("Duplicate IDs across catalogs")
        all_ids.update(ids)
        old = target.read_bytes() if target.exists() else None
        # Git may expose LF while a clean Windows checkout uses CRLF. Keep
        # the local style instead of rewriting identical JSON on every sync.
        if old is not None and old.replace(b"\r\n", b"\n") == data.replace(b"\r\n", b"\n"):
            file_states[relative] = sha256(old)
            continue
        if old is not None:
            if dirty_check(root, relative) and applied.get(relative) != sha256(old):
                raise ValueError(f"Local edits preserved: {relative}")
            validate_transition(json.loads(old.decode("utf-8-sig")), current)
        elif not all(r["status"] != "active" or approval_valid(r) for r in ids.values()):
            raise ValueError("New active catalog lacks recorded approval")
        output = data
        if old is not None and b"\r\n" in old:
            output = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        updates[relative] = (old, output)
        file_states[relative] = sha256(output)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    written = []
    try:
        with tempfile.TemporaryDirectory(dir=state_path.parent) as staging:
            for relative, (_, data) in updates.items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                staged = Path(staging) / target.name
                staged.write_bytes(data)
                staged.replace(target)
                written.append(relative)
            staged_state = Path(staging) / "state.json"
            staged_state.write_text(json.dumps({"commit":commit,
                "files":file_states},indent=2)+"\n", encoding="utf-8")
            staged_state.replace(state_path)
    except Exception:
        for relative in reversed(written):
            old = updates[relative][0]
            if old is None:
                (root / relative).unlink(missing_ok=True)
            else:
                (root / relative).write_bytes(old)
        raise
    return len(updates)


def api(path):
    url = f"https://api.github.com/repos/{REPOSITORY}/{path}"
    if sys.platform == "win32":
        # Use the Windows trust store, including locally installed issuer CAs,
        # rather than weakening TLS verification for a background Python process.
        if not re.fullmatch(r"[A-Za-z0-9_./?=&-]+", path):
            raise ValueError("Unexpected GitHub API path")
        script = (
            "$ErrorActionPreference='Stop';"
            "[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false);"
            f"Invoke-RestMethod -Uri '{url}' -TimeoutSec 30 "
            "-Headers @{Accept='application/vnd.github+json';"
            "'User-Agent'='math-trainer-template-sync'} | ConvertTo-Json -Depth 100 -Compress"
        )
        response = subprocess.run(
            ["powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True, encoding="utf-8", check=True, timeout=45,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        return json.loads(response.stdout.lstrip("\ufeff"))
    request = urllib.request.Request(url,
        headers={"Accept":"application/vnd.github+json","User-Agent":"math-trainer-template-sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def sync_once(root):
    root = Path(root).resolve()
    commit = api("commits/main")
    state_path = root / ".dart_tool/template-sync.json"
    if state_path.exists() and json.loads(state_path.read_text(encoding="utf-8")).get("commit") == commit["sha"]:
        return 0
    tree = api(f"git/trees/{commit['commit']['tree']['sha']}?recursive=1")
    if tree.get("truncated"):
        raise ValueError("Incomplete remote tree")
    downloads = {}
    for item in tree["tree"]:
        if item["type"] != "blob" or not PATH.fullmatch(item["path"]):
            continue
        blob = api(f"git/blobs/{item['sha']}")
        if blob.get("encoding") != "base64":
            raise ValueError("Unsupported blob encoding")
        data = base64.b64decode(blob["content"])
        expected = hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest()
        if expected != item["sha"]:
            raise ValueError("Damaged GitHub blob")
        downloads[item["path"]] = data
    return apply_downloads(root, downloads, commit["sha"])


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--root",default=".")
    parser.add_argument("--watch",action="store_true")
    parser.add_argument("--interval",type=int,default=300)
    args=parser.parse_args()
    if args.interval < 300:
        parser.error("Public GitHub polling interval must be at least 300 seconds")
    while True:
        try:
            changed=sync_once(args.root)
            print(f"Template sync: {changed} files updated",flush=True)
        except Exception as error:
            print(f"Template sync stopped safely: {error}",flush=True)
            if not args.watch:
                raise SystemExit(1) from error
        if not args.watch:
            return
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
