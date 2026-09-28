#!/usr/bin/env python3
"""Read-only migration source guard. No database, network or deployment access."""
from __future__ import annotations
import argparse, hashlib, json, os, re
from pathlib import Path
PREFIX = re.compile(r"^(\d+)_.*\.sql$")
KNOWN_HANDOFFS = {
 "0003_server_handoff_recovery.sql": "b992f0af381a14646fcc6522298e03214cc2fc3155070f56987f746512bad59a",
 "0003_payment_handoff_journal.sql": "9d9996f474dce1e46d12b7995c61ace2a3bc11a93c36a31b0f4c5a51fae43ff9",
}
def check(root: Path) -> dict:
    root = Path(os.path.abspath(root.expanduser()))
    problems, groups, handoff = [], [], []
    if not root.is_dir() or any(p.is_symlink() for p in [root, *root.parents]):
        return {"passed": False, "problems": ["Root must be an existing non-symlink directory"], "remoteMigrationAuthorized": False}
    for directory, dirs, names in os.walk(root, followlinks=False):
        here=Path(directory)
        dirs[:] = [d for d in dirs if d not in {'.git','node_modules','output','build','.dart_tool','.next','__pycache__'}]
        for d in list(dirs):
            if (here/d).is_symlink():
                problems.append(f"Symlinked source directory: {(here/d).relative_to(root)}");dirs.remove(d)
        if here.name != 'migrations': continue
        versions={}
        for name in sorted(names):
            path=here/name
            if path.is_symlink(): problems.append(f"Symlinked migration: {path.relative_to(root)}");continue
            match=PREFIX.fullmatch(name)
            if not match: continue
            version=str(int(match.group(1)));versions.setdefault(version,[]).append(name)
            if here.relative_to(root).as_posix()=='cloudflare/payment-allocation/migrations' and version=='3':
                sha=hashlib.sha256(path.read_bytes()).hexdigest()
                recognized=KNOWN_HANDOFFS.get(name)==sha
                handoff.append({"path":str(path.relative_to(root)),"sha256":sha,"recognizedSourceVariant":recognized})
                if not recognized:problems.append(f"Unreviewed payment handoff migration variant: {name}")
        for version, names_at_version in versions.items():
            if len(names_at_version)>1: problems.append(f"Duplicate migration version {version} in {here.relative_to(root)}: {', '.join(names_at_version)}")
        groups.append({"directory":str(here.relative_to(root)),"versions":versions})
    return {"schemaVersion":1,"passed":not problems,"problems":problems,"directories":groups,
      "observedHandoffVariants":handoff,"knownConflictingHandoffSources":KNOWN_HANDOFFS,
      "scope":"Filesystem names and SHA-256 only; no deployed database history inspected",
      "historicalConflictReconciled":False,"remoteMigrationAuthorized":False}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,required=True);args=parser.parse_args()
    try: result=check(args.root)
    except OSError as e: result={"passed":False,"problems":["Source cannot be inspected: "+type(e).__name__],"remoteMigrationAuthorized":False}
    print(json.dumps(result,indent=2));return 0 if result['passed'] else 2
if __name__=='__main__':raise SystemExit(main())
