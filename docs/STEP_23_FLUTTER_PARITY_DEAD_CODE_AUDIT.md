# MAXI STEP 23 — Flutter Parity & Dead-Code Audit

Baseline: `main @ b73a1f89f82cdbda76cd6aa9120002191a30b68a`  
Date: 2026-10-06  
Scope: parity/cutover truth, dead/duplicate code, unreachable-but-planned infrastructure, repository hygiene and the safe cleanup that can be performed without changing product behavior.

## Verdict

Step 23 is complete as a **structural audit + safe dead-code cleanup**.

The Flutter baseline is the only active runtime source tree in the repository. The former Kotlin/Compose implementation is retained only inside `wanderlog-memories (2).zip` as donor/reference evidence. That ZIP is intentionally **not deleted** in this step because production cutover parity and Room -> Drift migration evidence are still open.

The audit does **not** claim full Kotlin -> Flutter parity. The current state is:

| Area | Flutter state | Parity verdict | Blocking follow-up |
|---|---|---|---|
| Journey core | create/read + detail/timeline/map present | PARTIAL | canonical Premium gate; edit/archive/delete UX |
| Memory core | create/read/edit + unassigned Memory support | PARTIAL | canonical Premium gate; delete/library UX |
| Album/photos | import/persistence/relations present | PARTIAL | real image thumbnails/viewer; delete/favorite/cover UX |
| Capture | functional capture pipeline + Premium checks | SUBSTANTIAL | converge creation policy with normal UI/E2 |
| Keepsakes/Documents | import/persistence present | PARTIAL | open/share/delete/error handling |
| Smart Journey | engine/policy/integration present | PARTIAL | parity/runtime acceptance remains |
| Map Memories | map/clustering/replay path present | PARTIAL | route truthfulness; offline-map engine |
| Rediscover/Replay | engine/UI present | PARTIAL | MemoryPhoto association correctness |
| Premium/RevenueCat | entitlement foundation present | NOT CUTOVER-READY | one canonical creation policy; truthful benefit list |
| Cloud backup/sync | domain/data implementation present | NOT RUNTIME-WIRED | explicit runtime wiring + backup UI + restore drills |
| Localization | six-locale foundation present | PARTIAL | zero untranslated release gate |
| Android/Web | release builds exist in CI | PARTIAL DELIVERY | stable Web deploy, release signing, smaller APK |
| iOS | platform scaffold generated | NOT VERIFIED | macOS/iOS build gate |
| Room -> Drift | compatibility code present | NOT CERTIFIED | deterministic v8->v9 fixture + physical Room v6 upgrade |

## Dead-code classification

### Removed now — proven duplicate

`DriftJourneyRepository` was a second Journey repository implementation. Code search proved that production uses `DriftWonderlogRepository`, which already implements `JourneyRepository`; the duplicate was referenced only by its own unit test.

Step 23 therefore:
- removes `flutter/lib/features/journeys/data/drift_journey_repository.dart`;
- retargets `journey_repository_test.dart` to the production `DriftWonderlogRepository`;
- keeps the `JourneyRepository` interface because it remains the domain boundary used by production presentation/components.

### Keep — not dead

The following are intentionally **not** removed even when current runtime wiring is incomplete:

- cloud backup/sync classes: approved future runtime path, not obsolete;
- `OfflineMapRegions`: incomplete capability but part of the approved Premium/maps roadmap;
- `LegacyDatabaseCompatibility`: required for Room v6 -> Drift v9 cutover;
- Shared Ecosystem Core / Life Bridge adapters: active and CERTIFIED GOLDEN for the tested Android Wonderlog <-> Anna scope;
- `wanderlog-memories (2).zip`: current donor/reference package until parity and migration cutover evidence is closed.

Deleting any of those in a dead-code sweep would destroy planned or migration-critical capability rather than remove redundancy.

## Structural findings carried forward

The audit confirms the current deep-audit blockers rather than inventing a second roadmap:

1. E2 materialization is not yet atomic exactly-once; the inbox row is resolved after domain writes and a stale in-memory `isPending` check is not a concurrency lock.
2. Premium policy is fragmented. Normal Journey/Memory creation can bypass gates; Capture uses per-Journey Memory counts; E2 incorrectly uses a global Memory count for a per-Journey limit.
3. Drift v9 migration lacks deterministic existing-data fixture coverage and physical Room v6 upgrade evidence.
4. E2 has unit coverage for all four materialization actions, but not complete UI/concurrency coverage.
5. Media/Keepsakes/delete/archive parity is still below production cutover.
6. Cloud/offline-map code must be treated as implemented infrastructure, not shipped runtime capability.
7. Search N+1/O(n), Rediscover photo association and fixed-English OSM search remain P2 performance/correctness work.
8. Stable Web deploy, iOS build, production signing, localization completion and release versioning remain release-hardening work.

## Donor evidence limitation

The Kotlin donor is an opaque ZIP in the Git tree rather than an extracted source tree. Repository-level parity therefore cannot be mechanically proven class-by-class from the current source tree. Existing migration documentation and compatibility contracts are usable evidence, but final parity remains gated on the donor/reference package plus physical legacy-data validation.

This is an evidence limitation, not a reason to copy the donor back into production source.

## Step 23 gate

PASS for:
- current Flutter runtime inventory;
- identification of proven duplicate repository code;
- safe duplicate removal;
- classification of unwired-but-approved modules vs true dead code;
- parity/cutover gap matrix;
- roadmap realignment.

NOT PASSED / intentionally deferred:
- full product parity;
- Premium correctness;
- exactly-once E2 materialization;
- migration certification;
- physical device cutover;
- production release readiness.

Those belong to the repair sequence beginning with **MAXI STEP 23A — E2 Hardening**.
