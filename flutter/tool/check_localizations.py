#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARB_DIR = ROOT / "lib" / "l10n"
TEMPLATE = ARB_DIR / "app_en.arb"
LOCALES = ("it", "es", "fr", "de", "pt")


def load(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def message_keys(data: dict) -> set[str]:
    return {key for key in data if not key.startswith("@")}


def placeholder_names(message: str) -> set[str]:
    # ARB placeholders always begin with an identifier inside an ICU brace.
    return set(re.findall(r"\{([A-Za-z][A-Za-z0-9_]*)", message))


def main() -> int:
    template = load(TEMPLATE)
    template_keys = message_keys(template)
    failures: list[str] = []

    for locale in LOCALES:
        path = ARB_DIR / f"app_{locale}.arb"
        data = load(path)
        keys = message_keys(data)

        missing = sorted(template_keys - keys)
        extra = sorted(keys - template_keys)
        if missing:
            failures.append(f"{locale}: missing keys: {', '.join(missing)}")
        if extra:
            failures.append(f"{locale}: extra keys: {', '.join(extra)}")

        for key in sorted(template_keys & keys):
            value = data[key]
            if not isinstance(value, str) or not value.strip():
                failures.append(f"{locale}:{key}: empty/non-string translation")
                continue
            expected = placeholder_names(str(template[key]))
            actual = placeholder_names(value)
            if expected != actual:
                failures.append(
                    f"{locale}:{key}: placeholders {sorted(actual)} != "
                    f"template {sorted(expected)}"
                )

    if failures:
        print("LOCALIZATION GATE: FAIL", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(
        "LOCALIZATION GATE: PASS — "
        f"{len(template_keys)} user-facing keys aligned across "
        f"{1 + len(LOCALES)} locales."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
