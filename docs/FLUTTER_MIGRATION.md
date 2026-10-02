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
tag converter format. Flutter advances the schema non-destructively to v8,
adding only the new ecosystem inbox/outbox tables. Fresh installs and
non-Android platforms use the Flutter database path.

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

Private local media URIs are not part of the wire contract. Binary media is
represented by an explicit handoff descriptor. Wonderlog E1 currently uses
the safe `omitted` handoff until a binary transport is separately certified.

Transport remains separate from the envelope:
- local v1 deep link: `<targetScheme>://ecosystem/import?payload=...`;
- portable clipboard fallback: `ECOSYSTEM_BRIDGE_V1:...`;
- optional cloud transport later, behind provider-specific adapters.

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
- Life Bridge v1 remains only a compatibility projection from the common
  envelope; it is no longer the primary shared contract.

The candidate Golden is frozen in
`docs/GOLDEN_ECOSYSTEM_BRIDGE_CONTRACT_v1_DRAFT.txt`. It becomes eligible for
COPY-READY promotion only after Anna's Diary implements its definitive
consumer adapter and both apps pass the same cross-app contract tests.

## Migration gates

The Flutter build cannot become the main Wonderlog release until:

- Journey/Memory/Album parity is complete;
- Capture/Keepsakes parity is complete;
- Smart Journey parity is complete;
- Map Memories parity is complete;
- Rediscover/Replay parity is complete;
- Premium/RevenueCat parity is complete;
- cloud backup/sync parity is complete;
- legacy Android Room v6 -> Flutter Drift v8 cutover is verified on a real device;
- Android release and Web release builds pass;
- iOS build passes on macOS;
- no destructive migration or silent data loss is possible.

## Current certification snapshot

The Flutter foundation has been merged into `main` after passing
localization/code generation, static analysis, unit tests, Web release build,
Android release APK, Android AAB and artifact packaging. Ecosystem E1 is
validated through its own pull-request gate before merge.

The remaining production cutover evidence is primarily real-device validation
of the existing Room database migration and a macOS/iOS build gate.
