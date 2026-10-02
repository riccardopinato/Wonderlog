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

The shared interoperability primitive is `EcosystemEnvelope v1`.

Every app keeps its own database and domain model. Cross-app exchange happens
through a versioned envelope with explicit source identity, entity identity,
timestamps, tags, people, places, media references and an idempotency key.

No app is allowed to read another app's private database directly.

Transport is intentionally separate from the envelope. Planned adapters are:

- local Android/iOS share/deep-link transport;
- optional authenticated Supabase inbox/outbox;
- import confirmation in the destination app.

## Anna's Diary Life Bridge v1 adapter

The Flutter migration now contains the first concrete cross-app adapter for
Anna's Diary.

- Wonderlog keeps `EcosystemEnvelope v1` as its internal interoperability
  primitive, then projects an explicitly shared Journey into Anna's canonical
  `Life Bridge v1` wire contract.
- Journey export supports distinct `COPY` and `LINK` intents.
- The exported `bridgeId` is deterministic for
  `source app + entity type + entity id + revision`, so repeating the same
  export is idempotent in Anna.
- A private envelope cannot cross the bridge boundary. Export requires
  `explicitShare`.
- Local media URIs are never exported. v1 carries only safe media metadata and
  declares binary transfer as omitted.
- Anna remains the destination owner after materialization: Wonderlog never
  reads Anna's database, keys, sync state or private stores.
- Current transport is deliberately explicit clipboard handoff. This is a
  real end-to-end contract test, not background synchronization.
- The adapter is part of the Flutter migration branch and must not be marketed
  as a production connection until the Flutter client passes the migration
  gates below.

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

The Flutter foundation CI currently passes localization/code generation,
static analysis, unit tests, Web release build, Android release APK, Android
AAB and artifact packaging on the migration branch. The PR remains the
integration boundary until the branch is merged into `main`.

The remaining production cutover evidence is primarily real-device validation
of the existing Room database migration and a macOS/iOS build gate.


## Shared Ecosystem Core v1 — E1 candidate

The migration now extracts the existing ecosystem groundwork into a reusable
Shared Ecosystem Core v1 candidate.

- EcosystemEnvelope keeps canonical source identity and now exposes a
  deterministic bridgeId, explicit transfer mode, provenance, fallback and
  required capabilities.
- COPY and LINK are separate intents while the canonical source revision keeps
  one stable bridge identity, while handoff idempotency remains mode-aware.
- Cross-app serialization strips private local media references and preserves
  only safe metadata.
- EcosystemRegistry performs target capability negotiation before a handoff.
- EcosystemLocalTransport persists the outbox first, then prepares a
  target-specific deep-link packet plus explicit encoded/plain-text fallback.
- Receiving a packet persists it in the inbox and does not silently materialize
  destination data.
- The cloud bridge remains outside E1 and must be implemented as a separate,
  optional transport.

The extraction is documented as
GOLDEN_ECOSYSTEM_BRIDGE_FLUTTER_v1_CANDIDATE. It must not be promoted to
Golden until Wonderlog <-> Anna real-device COPY/LINK round-trip and all
certification gates pass.
