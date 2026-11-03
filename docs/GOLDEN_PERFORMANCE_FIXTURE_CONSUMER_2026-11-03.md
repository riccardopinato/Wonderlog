# Independent Performance Fixtures consumer — Wonderlog
Date: 2026-11-03

Core source pinned to App-Factory-Core@f5b97a2fc866fdc18c3f87f21147e1539dc37742.
Test-only vendor sources (spatial copy has a braces-only analyzer fix):
- reference_engines/lib/src/performance_fixtures.dart
  -> flutter/test/support/performance_fixtures.dart,
  blob ee42172a3267e7ea648816c2c38768bab79362e7
- reference_engines/lib/src/spatial_clustering.dart
  -> flutter/test/support/spatial_clustering.dart,
  upstream blob 631b0b91a22e42566af832ceaeb8fa593d232de9; vendored blob differs only by braces around zero-distance early return

Real consumer workload:
flutter/test/golden_performance_fixture_consumer_test.dart constructs 300
deterministically seeded Journey records with legitimate coordinates, executes
WonderlogSearchEngine.search directly over 5 measured repetitions plus 2
warmups, verifies identity and output count, and emits a JSON benchmark receipt
with checked-out Git SHA (no fabricated fallback), runner identity, p50/p95 and checksum.

No universal speed threshold. CI performance is not physical battery, thermal,
FPS or actual-device memory certification. This is a test-only independent
consumer for the fixture harness, not for the spatial clustering functionality.

Exact PR head Flutter Foundation must run all tests, analyze and build gates
before declaring consumer verified.
