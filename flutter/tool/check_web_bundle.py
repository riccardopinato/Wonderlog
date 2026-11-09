#!/usr/bin/env python3
"""Fail-closed, reproducible SQLite/Drift WASM distribution checks.

The GitHub Pages build generates web/ from Flutter's template. These runtime
files must be added after generation; Flutter analyze/build alone does not
verify that a browser can open its local Drift database.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

# Verified from upstream immutable release assets (not untrusted CDN paths).
# drift_worker.js: simolus3/drift release drift-2.31.0
# sqlite3.wasm: simolus3/sqlite3.dart release sqlite3-2.9.4
ASSETS = {
    "drift_worker.js": (
        355298,
        "f0a9b87085f732fd7b6ee7eb34d3858c556f05d221eb1febfc443649cd365752",
    ),
    "sqlite3.wasm": (
        730989,
        "922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117",
    ),
}
RESOLVED = {"drift": "2.31.0", "sqlite3": "2.9.4"}


def verify_dependencies() -> None:
    payload = subprocess.check_output(
        ["dart", "pub", "deps", "--json"], text=True
    )
    packages = {
        entry["name"]: entry["version"]
        for entry in json.loads(payload)["packages"]
    }
    for package, expected in RESOLVED.items():
        if packages.get(package) != expected:
            raise RuntimeError(
                f"Unexpected {package}: {packages.get(package)!r}; "
                f"web assets require {expected}. Update their upstream "
                "release and hashes together, do not silently upgrade."
            )


def verify_assets(root: Path) -> None:
    for filename, (expected_size, digest) in ASSETS.items():
        path = root / filename
        if not path.is_file():
            raise RuntimeError(f"Missing required browser runtime: {path}")
        raw = path.read_bytes()
        if len(raw) != expected_size:
            raise RuntimeError(f"Unexpected asset size: {path}")
        actual = hashlib.sha256(raw).hexdigest()
        if actual != digest:
            raise RuntimeError(f"Unverified upstream asset: {path}")
        if filename.endswith(".wasm") and raw[:4] != bytes((0, 97, 115, 109)):
            raise RuntimeError(f"Invalid WASM header: {path}")


def verify_distribution(expected_base_href: str) -> None:
    output = Path("build/web")
    verify_assets(output)
    index = output / "index.html"
    bootstrap = output / "flutter_bootstrap.js"
    if not index.is_file() or not bootstrap.is_file():
        raise RuntimeError("Missing Flutter Web index/bootstrap from output")
    html = index.read_text(encoding="utf-8")
    if f'<base href="{expected_base_href}">' not in html:
        raise RuntimeError(f"Incorrect Web base href: expected {expected_base_href}")
    # Upload this exact directory; do not copy another build afterwards.


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-href", default="/Wonderlog/")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--deps", action="store_true")
    group.add_argument("--assets", action="store_true")
    group.add_argument("--dist", action="store_true")
    args = parser.parse_args()
    if args.deps:
        verify_dependencies()
    elif args.assets:
        verify_assets(Path("web"))
    elif args.dist:
        verify_distribution(args.base_href)
    print("Wonderlog Web distribution gate: PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError) as exc:
        print(f"Wonderlog Web distribution gate: FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
