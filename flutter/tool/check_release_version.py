#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / "pubspec.yaml"
VERSION_RE = re.compile(
    r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$",
    re.MULTILINE,
)


def main() -> int:
    text = PUBSPEC.read_text(encoding="utf-8")
    match = VERSION_RE.search(text)
    if match is None:
        print(
            "RELEASE VERSION GATE: FAIL — expected semver+build in pubspec.yaml",
            file=sys.stderr,
        )
        return 1

    major, minor, patch, build = map(int, match.groups())
    if build <= 0:
        print("RELEASE VERSION GATE: FAIL — build number must be positive", file=sys.stderr)
        return 1

    if (major, minor, patch, build) == (0, 1, 0, 1):
        print(
            "RELEASE VERSION GATE: FAIL — bootstrap version 0.1.0+1 is forbidden",
            file=sys.stderr,
        )
        return 1

    print(
        "RELEASE VERSION GATE: PASS — "
        f"{major}.{minor}.{patch}+{build}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
