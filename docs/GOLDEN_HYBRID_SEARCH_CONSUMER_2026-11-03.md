# Golden Hybrid Local Search — Wonderlog consumer pilot
Date: 2026-11-03. Scope: local search for Journeys and Memories.

Core canonical reference: App-Factory-Core@a9a051d2dbb1a89ad7eacad8a3d7d293087fe182
- reference_engines/lib/src/hybrid_search.dart: immutable blob 95de49c3e531451b8984461223a6a5fb1d9cc1f1
- reference_engines/lib/src/semantic_embeddings.dart: immutable blob de96c2dbf0da2c0c4695308efd5b9bbab25b75f5

Vendored BYTE-IDENTICAL in:
- flutter/lib/features/search/domain/hybrid_search.dart
- flutter/lib/features/search/domain/semantic_embeddings.dart

Real app call site: flutter/lib/features/search/domain/search_engine.dart, invoked
by flutter/lib/features/search/presentation/global_search_page.dart.
The existing substring/diacritic-insensitive search remains default.
An explicit, localized FilterChip opts in to "Include related terms" based on
deterministic feature hashing, NOT a trained neural model or remote AI.
All six existing locale ARBs include the new control text. Search data is
assembled only from the caller's local repository streams; there are no remote
calls or persisted derived embeddings.

Consumer tests: flutter/test/golden_hybrid_search_consumer_test.dart
and existing flutter/test/search_engine_test.dart.
Gate: Wonderlog Flutter Foundation exact PR head
Flutter analyze, all tests, Web + Android output build.
No persistence migration, new permissions, billing, network or subscription.

Limitations: this consumer is an independent third app for search (not Notes
or CamperBoss), but verifies only local ephemeral search and opt-in feature-hash
matching. It does not validate persistent index revision, large-data latency,
neural semantic quality, sharing/account isolation or Play/device runtime.
Do not declare full Golden E5 until exact-head CI and app-specific review.
