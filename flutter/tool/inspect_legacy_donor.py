#!/usr/bin/env python3
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DONOR = ROOT.parent / "wanderlog-memories (2).zip"

if not DONOR.exists():
    raise SystemExit(f"Legacy donor ZIP not found: {DONOR}")

with zipfile.ZipFile(DONOR) as archive:
    names = archive.namelist()

    gradle_candidates = [
        name for name in names
        if name.endswith("/app/build.gradle.kts") or name == "app/build.gradle.kts"
    ]
    application_ids = []
    for name in gradle_candidates:
        text = archive.read(name).decode("utf-8", errors="replace")
        application_ids.extend(
            re.findall(r'applicationId\s*=\s*"([^"]+)"', text)
        )

    schema_candidates = [
        name for name in names
        if name.endswith("/6.json") and "schema" in name.lower()
    ]
    schemas = []
    for name in schema_candidates:
        try:
            data = json.loads(archive.read(name))
        except Exception:
            continue
        database = data.get("database", {})
        entities = database.get("entities", [])
        schemas.append({
            "path": name,
            "version": database.get("version"),
            "identityHash": database.get("identityHash"),
            "entities": [
                {
                    "tableName": entity.get("tableName"),
                    "createSql": entity.get("createSql"),
                    "fields": [
                        {
                            "fieldPath": field.get("fieldPath"),
                            "columnName": field.get("columnName"),
                            "affinity": field.get("affinity"),
                            "notNull": field.get("notNull"),
                            "defaultValue": field.get("defaultValue"),
                        }
                        for field in entity.get("fields", [])
                    ],
                }
                for entity in entities
            ],
        })

    room_sources = []
    for name in names:
        if not name.endswith(".kt"):
            continue
        text = archive.read(name).decode("utf-8", errors="replace")
        if (
            "@Entity" in text
            or "@Database" in text
            or "class Converters" in text
            or "object Converters" in text
        ):
            room_sources.append({
                "path": name,
                "content": text,
            })

print(json.dumps({
    "applicationIds": sorted(set(application_ids)),
    "roomV6Schemas": schemas,
    "roomSourceFiles": room_sources,
}, indent=2, ensure_ascii=False))
