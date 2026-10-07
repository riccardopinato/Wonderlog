# Wonderlog — Flutter migration

## Baseline

The Kotlin/Compose project stored in the repository ZIP remains the donor
baseline. The Flutter implementation is developed in parallel under
`flutter/` until parity is proven.

## Why parallel migration

A direct rewrite would create unnecessary regression and data-loss risk.
The migration therefore follows COPY-FIRST and Architecture Before Scale:

1. freeze the Kotlin feature semantics;
2. port infrastructure using the Project Golden Components;
3. port the stable domain/data contracts;
4. port features by bounded vertical slices;
5. add legacy export/import before production package cutover;
6. certify Android, iOS and Web independently.

## Golden components reused

- Universal Identity: Anna's Diary donor, Supabase + Google OAuth;
- Localization: FrameLab/Anna's Diary ARB pattern;
- Profile: repository + local preference pattern;
- Material 3 theme: shared design-token pattern;
- CI/release: generated platform shells, analyze/test/build and artifacts.

## Data compatibility

Flutter Drift uses the same conceptual entities and table names as the current
Room model:

- trips;
- memories;
- album_photos;
- memory_photos;
- memory_attachments;
- location_places;
- geocoding_cache;
- offline_map_regions.

The Android cutover path now preserves the legacy Room database in place.
Flutter detects the production Android database filename and opens it through
Drift using schema-compatible table/column mappings, including the Room v6
tag converter format. E1 introduced schema v8 with ecosystem inbox/outbox.
E2 advances the current Flutter schema to v9, making the Memory-to-Journey
relationship optional for true unassigned Memories and adding durable inbox
resolution metadata.

Step 27 adds a fail-closed pre-open safety snapshot for the detected production
Room database. DB + present WAL/SHM sidecars are copied into private migration
backup storage and SHA-256 verified before Drift may open the legacy file.
A Room-v6-shaped -> Drift-v9 fixture is CI-green, and a separate drill harness
migrates only a working copy of an actual legacy DB. Real-user-copy and
physical-device migration evidence is still required before production cutover.

Fresh installs and non-Android platforms use the Flutter database path.

## Ecosystem direction

The canonical interoperability primitive is now **Shared Ecosystem Core v1**.

Every app keeps its own database, repository and domain model. No app reads
another app's private database directly.

The common `EcosystemEnvelope v1` carries:
- stable `bridgeId`;
- explicit COPY or LINK semantics;
- source revision and idempotency key;
- canonical-owner provenance;
- fallback data;
- tags, people and places;
- safe media metadata plus explicit handoff descriptors.

`bridgeId` is stable across revisions. The idempotency key combines
`bridgeId + revision + transfer mode`, so COPY and LINK are distinct
deliveries and a new source revision remains independently deliverable.

Pre-E1 schema-v8 keys are treated as legacy COPY identities only. They remain
compatible without suppressing LINK deliveries for the same source revision.
Concurrent duplicate delivery is protected by durable unique-key insertion.

Private local media URIs are not part of the wire contract. Binary media is
represented by an explicit handoff descriptor. Wonderlog E1 currently uses
the safe `omitted` handoff until a binary transport is separately certified.

Transport remains separate from the envelope:
- local v1 deep link: `<targetScheme>://ecosystem/import?payload=...`;
- portable clipboard fallback: `ECOSYSTEM_BRIDGE_V1:...`;
- optional cloud transport later, behind provider-specific adapters.

Malformed local transport packages are normalized to a stable
`FormatException` error surface and fail closed before durable materialization.

### Anna's Diary first integration

Wonderlog is the first producer implementation.

- Journey and Memory adapters emit Shared Core v1 envelopes.
- COPY keeps the source original canonical in Wonderlog and permits an
  independent destination copy.
- LINK requires a canonical Wonderlog deep link and preserves source
  ownership.
- Anna's Diary is registered with the target route
  `annasdiary://ecosystem/import`.
- If Anna's Diary is unavailable, Wonderlog copies a machine-readable portable
  package and keeps the outbox delivery retryable.
- Life Bridge v1 remains a compatibility projection from the common envelope;
  it is implemented and functioning on the Wonderlog producer side but is no
  longer the primary shared contract.

The Wonderlog E1 producer baseline was hardened in PR #5, passed the complete
Flutter CI gate on tested head
`25578cade1f9dd32712d495b13caaf2ead9e8ea7` (run `37023549635`) and was
squash-merged to `main` as
`77e6b11342e6b81ea9e5ecc0d9b731b4dc90a4c5`.

The Shared Ecosystem Core v1 contract is CERTIFIED GOLDEN for the physically
tested Android Wonderlog ↔ Anna's Diary scope. The historical contract filename
still contains `DRAFT`, but the status inside the contract is authoritative.

## Step 23 parity / dead-code checkpoint

The post-E2 parity audit uses Flutter as the only active runtime baseline and
keeps the Kotlin/Compose ZIP strictly as donor/reference evidence until cutover.

One implementation was proven redundant and removed:
`DriftJourneyRepository`. Its tests now target the canonical
`DriftWonderlogRepository`, which already implements the Journey contract.

Cloud, offline-map, legacy-database and ecosystem modules are not classified as
dead merely because their full production paths are unfinished. They remain
approved migration/cutover dependencies and must be completed or explicitly
retired by their owning roadmap steps.

See `STEP_23_FLUTTER_PARITY_DEAD_CODE_AUDIT.md` for the parity matrix and
evidence limits.

## Migration gates

The Flutter build cannot become the main Wonderlog release until:

- Journey/Memory/Album parity is complete;
- Capture/Keepsakes parity is complete;
- Smart Journey parity is complete;
- Map Memories parity is complete;
- Rediscover/Replay parity is complete;
- Premium/RevenueCat parity is complete;
- cloud backup/sync parity is complete;
- legacy Android Room v6 -> Flutter Drift v9 cutover is verified on a real device;
- Android split release APK and AAB builds pass;
- stable Web deploy is verified after merge;
- iOS release no-codesign build passes on macOS;
- production Android signing is verified with the persistent release identity;
- a copy of a real Room v6 user database passes the migration drill;
- physical Android update confirms the legacy cutover with no data loss;
- no destructive migration or silent data loss is possible.

## Current certification snapshot

The Flutter foundation has been merged into `main` after passing
localization/code generation, static analysis, unit tests, Web release build,
Android release APK, Android AAB and artifact packaging.

E1 is CERTIFIED GOLDEN for the tested Android Wonderlog ↔ Anna's Diary path.
E2 is merged and adds the official inbound Ecosystem Inbox UX. Full-product
production certification remains separate and is tracked in
`docs/AUDIT_2026-10-06.md`.

The remaining full-production cutover evidence is separate from E1 handoff
readiness. Step 27 has closed the deterministic localization/version/ABI/Apple
compile gates; the remaining blockers are primarily a real Room-v6
copy/device cutover drill, production signing/distribution evidence, store
configuration and the remaining provider/device validation.
