#!/usr/bin/env python3
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DONOR = ROOT.parent / "wanderlog-memories (2).zip"

EXPECTED_APPLICATION_ID = "com.aistudio.wanderlogmemories.pqrzmx"
EXPECTED_DATABASE_NAME = "wanderlog-memories-db"
EXPECTED_DATABASE_VERSION = 6
EXPECTED_TABLES = {
    "trips",
    "memories",
    "album_photos",
    "memory_photos",
    "location_places",
    "geocoding_cache",
    "offline_map_regions",
    "cloud_sync_queue",
    "memory_attachments",
}

if not DONOR.exists():
    raise SystemExit(f"Legacy donor ZIP not found: {DONOR}")

with zipfile.ZipFile(DONOR) as archive:
    names = archive.namelist()

    application_ids = []
    legacy_version_codes = []
    source_files = {}
    for name in names:
        if name.endswith("/app/build.gradle.kts") or name == "app/build.gradle.kts":
            text = archive.read(name).decode("utf-8", errors="replace")
            application_ids.extend(
                re.findall(r'applicationId\s*=\s*"([^"]+)"', text)
            )
            legacy_version_codes.extend(
                int(value)
                for value in re.findall(r"versionCode\s*=\s*(\d+)", text)
            )

        if name.endswith(".kt"):
            text = archive.read(name).decode("utf-8", errors="replace")
            if (
                "@Entity" in text
                or "@Database" in text
                or "class Converters" in text
                or "object Converters" in text
                or "DatabaseMigrations" in text
            ):
                source_files[name] = text

    ids = sorted(set(application_ids))
    version_codes = sorted(set(legacy_version_codes))
    if ids != [EXPECTED_APPLICATION_ID]:
        raise SystemExit(
            "Legacy donor applicationId mismatch: "
            f"expected {EXPECTED_APPLICATION_ID}, found {ids}"
        )

    if len(version_codes) != 1:
        raise SystemExit(
            f"Expected one legacy versionCode, found {version_codes}"
        )
    legacy_version_code = version_codes[0]

    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    version_match = re.search(
        r"^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$",
        pubspec,
        flags=re.MULTILINE,
    )
    if version_match is None:
        raise SystemExit("Current Flutter build number not found in pubspec.yaml.")
    current_build_number = int(version_match.group(1))
    if current_build_number <= legacy_version_code:
        raise SystemExit(
            "Flutter build number must exceed legacy Android versionCode: "
            f"current={current_build_number}, legacy={legacy_version_code}"
        )

    joined = "\n".join(source_files.values())
    db_match = re.search(
        r"@Database\([\s\S]*?version\s*=\s*(\d+)[\s\S]*?"
        r"exportSchema\s*=\s*(true|false)",
        joined,
    )
    if db_match is None:
        raise SystemExit("Legacy donor @Database contract not found.")

    database_version = int(db_match.group(1))
    export_schema = db_match.group(2) == "true"
    if database_version != EXPECTED_DATABASE_VERSION:
        raise SystemExit(
            "Legacy donor database version mismatch: "
            f"expected {EXPECTED_DATABASE_VERSION}, found {database_version}"
        )
    if export_schema:
        raise SystemExit("Legacy donor unexpectedly exports Room schemas.")

    if EXPECTED_DATABASE_NAME not in joined:
        raise SystemExit(
            f"Legacy donor database name {EXPECTED_DATABASE_NAME!r} not found."
        )

    tables = set(re.findall(r'tableName\s*=\s*"([^"]+)"', joined))
    if tables != EXPECTED_TABLES:
        raise SystemExit(
            "Legacy donor Room table mismatch: "
            f"missing={sorted(EXPECTED_TABLES - tables)}, "
            f"extra={sorted(tables - EXPECTED_TABLES)}"
        )

    if 'joinToString(separator = "||")' not in joined:
        raise SystemExit("Legacy donor tag converter contract was not found.")

    source_hashes = {
        name: hashlib.sha256(text.encode("utf-8")).hexdigest()
        for name, text in sorted(source_files.items())
    }

contract = {
    "applicationId": EXPECTED_APPLICATION_ID,
    "legacyVersionCode": legacy_version_code,
    "currentFlutterBuildNumber": current_build_number,
    "databaseName": EXPECTED_DATABASE_NAME,
    "databaseVersion": database_version,
    "exportSchema": export_schema,
    "tables": sorted(tables),
    "tagSeparator": "||",
    "sourceFilesSha256": source_hashes,
    "result": "PASS",
}
print(json.dumps(contract, indent=2, ensure_ascii=False))
