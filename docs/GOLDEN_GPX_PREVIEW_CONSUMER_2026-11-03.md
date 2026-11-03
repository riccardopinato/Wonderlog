# Golden GPX independent Wonderlog consumer — read-only preview
Date: 2026-11-03

Canonical code: App-Factory-Core/reference_engines/lib/src/gpx.dart
Pinned source commit: 9adf94ed73e17b88806bbf4ef1d0d976ba244ff4
Source Git blob: 970b0555ab905655be4f6d221522b18cb37cc212
Vendored at flutter/lib/features/gpx/domain/gpx_reference.dart,
byte-identical by Git blob SHA.

Real product UI: the Journey Detail menu opens a local, read-only GPX file
preview. It uses file_picker (already depended upon by Wonderlog),
restricts extension to .gpx and checks up to 5MiB after file selection,
validates UTF-8, invokes GpxReferenceEngine.parse and presents tracks,
segments, routes, waypoints and the original point count.

No import, no persistence, no geotag reassignment, no route snapping, no
provider, no network. UI text localized for en/it/de/fr/es/pt.
Direct tests: flutter/test/gpx_preview_test.dart.

Evidence gates: Wonderlog Flutter Foundation analyze, all tests, Web, Android
ABI APK + AAB, Apple Build Gate; exact PR head must PASS before merge.
Even if green, E5 *independent consumer* is scoped to parse/validation/preview
only. Export interchange, on-device file permission/runtime, native file
picker availability and storage migration remain separate tests.

Important: this is NOT a full GPX import feature; the UI explicitly says
nothing is saved. Do not count this as full GPX Golden CERTIFIED or export
pipeline validation.
