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
Android release APK, Android AAB and artifact packaging.

The E1 Wonderlog producer/shared-contract side is now READY as the frozen
handoff baseline for Anna's Diary. Cross-app Golden certification remains
pending Anna's consumer implementation and the real bidirectional contract
round-trip.

The remaining full-production cutover evidence is separate from E1 handoff
readiness and is primarily real-device validation of the existing Room database
migration, remaining feature parity, and a macOS/iOS build gate.
