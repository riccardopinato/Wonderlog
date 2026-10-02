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

    with plist_path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)


if __name__ == "__main__":
    patch_android()
    patch_ios()
    print("Generated Android/iOS platform callbacks configured.")
