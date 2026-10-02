#!/usr/bin/env python3
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def patch_android() -> None:
    manifest_path = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.exists():
        raise SystemExit("AndroidManifest.xml not found. Generate Android platform first.")

    tree = ET.parse(manifest_path)
    root = tree.getroot()
    application = root.find("application")
    if application is None:
        raise SystemExit("Android application node not found.")

    target = None
    for activity in application.findall("activity"):
        name = activity.get(f"{{{ANDROID_NS}}}name", "")
        if name.endswith("MainActivity"):
            target = activity
            break
    if target is None:
        raise SystemExit("MainActivity not found.")

    already_present = False
    for intent_filter in target.findall("intent-filter"):
        for data in intent_filter.findall("data"):
            if data.get(f"{{{ANDROID_NS}}}scheme") == "com.riccardopinato.wonderlog":
                already_present = True
                break

    if not already_present:
        intent_filter = ET.SubElement(target, "intent-filter")
        ET.SubElement(
            intent_filter,
            "action",
            {f"{{{ANDROID_NS}}}name": "android.intent.action.VIEW"},
        )
        ET.SubElement(
            intent_filter,
            "category",
            {f"{{{ANDROID_NS}}}name": "android.intent.category.DEFAULT"},
        )
        ET.SubElement(
            intent_filter,
            "category",
            {f"{{{ANDROID_NS}}}name": "android.intent.category.BROWSABLE"},
        )
        ET.SubElement(
            intent_filter,
            "data",
            {
                f"{{{ANDROID_NS}}}scheme": "com.riccardopinato.wonderlog",
                f"{{{ANDROID_NS}}}host": "login-callback",
            },
        )

    # Canonical Wonderlog deep links used by LINK semantics and future
    # ecosystem imports. Keep one filter per host to avoid Android data
    # element cross-product matching.
    for host in ("journey", "memory", "ecosystem"):
        host_present = False
        for intent_filter in target.findall("intent-filter"):
            data_nodes = intent_filter.findall("data")
            host_present = any(
                data.get(f"{{{ANDROID_NS}}}scheme") == "wonderlog"
                and data.get(f"{{{ANDROID_NS}}}host") == host
                for data in data_nodes
            )
            if host_present:
                break

        if not host_present:
            intent_filter = ET.SubElement(target, "intent-filter")
            ET.SubElement(
                intent_filter,
                "action",
                {f"{{{ANDROID_NS}}}name": "android.intent.action.VIEW"},
            )
            ET.SubElement(
                intent_filter,
                "category",
                {f"{{{ANDROID_NS}}}name": "android.intent.category.DEFAULT"},
            )
            ET.SubElement(
                intent_filter,
                "category",
                {f"{{{ANDROID_NS}}}name": "android.intent.category.BROWSABLE"},
            )
            ET.SubElement(
                intent_filter,
                "data",
                {
                    f"{{{ANDROID_NS}}}scheme": "wonderlog",
                    f"{{{ANDROID_NS}}}host": host,
                },
            )

    # url_launcher canLaunchUrl() needs package visibility declarations on
    # Android 11+ for custom schemes used by sibling ecosystem apps.
    queries = root.find("queries")
    if queries is None:
        queries = ET.Element("queries")
        root.insert(0, queries)

    existing_query_schemes = {
        data.get(f"{{{ANDROID_NS}}}scheme")
        for intent in queries.findall("intent")
        for data in intent.findall("data")
    }
    for scheme in ("annasdiary", "notesapp", "trailpath"):
        if scheme in existing_query_schemes:
            continue
        intent = ET.SubElement(queries, "intent")
        ET.SubElement(
            intent,
            "action",
            {f"{{{ANDROID_NS}}}name": "android.intent.action.VIEW"},
        )
        ET.SubElement(
            intent,
            "data",
            {f"{{{ANDROID_NS}}}scheme": scheme},
        )

    tree.write(manifest_path, encoding="utf-8", xml_declaration=True)


def patch_ios() -> None:
    plist_path = ROOT / "ios" / "Runner" / "Info.plist"
    if not plist_path.exists():
        raise SystemExit("Info.plist not found. Generate iOS platform first.")

    with plist_path.open("rb") as handle:
        data = plistlib.load(handle)

    url_types = data.setdefault("CFBundleURLTypes", [])
    scheme = "com.riccardopinato.wonderlog"
    has_scheme = any(
        scheme in entry.get("CFBundleURLSchemes", [])
        for entry in url_types
        if isinstance(entry, dict)
    )
    if not has_scheme:
        url_types.append(
            {
                "CFBundleTypeRole": "Editor",
                "CFBundleURLSchemes": [scheme],
            }
        )

    wonderlog_scheme = "wonderlog"
    has_wonderlog_scheme = any(
        wonderlog_scheme in entry.get("CFBundleURLSchemes", [])
        for entry in url_types
        if isinstance(entry, dict)
    )
    if not has_wonderlog_scheme:
        url_types.append(
            {
                "CFBundleTypeRole": "Editor",
                "CFBundleURLSchemes": [wonderlog_scheme],
            }
        )

    query_schemes = data.setdefault("LSApplicationQueriesSchemes", [])
    for ecosystem_scheme in ("annasdiary", "notesapp", "trailpath"):
        if ecosystem_scheme not in query_schemes:
            query_schemes.append(ecosystem_scheme)

    with plist_path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)


if __name__ == "__main__":
    patch_android()
    patch_ios()
    print("Generated Android/iOS platform callbacks configured.")
