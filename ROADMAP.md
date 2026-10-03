# Wonderlog Roadmap

Execution truth as of 2026-10-03.

## DONE — Flutter foundation

- Flutter is the active cross-platform development baseline.
- Local-first Drift foundation is in place.
- Android/Web release builds are part of CI.
- Optional Supabase identity and localization/profile foundations are in place.
- Legacy Kotlin/Compose remains a donor/reference until production cutover.

## DONE — E1 Shared Ecosystem Core v1 producer baseline

Wonderlog producer-side baseline is complete and ready for Anna's Diary handoff.

Implemented and validated:

- versioned `EcosystemEnvelope v1`;
- stable bridge identity and provenance;
- COPY / LINK semantics;
- Journey and Memory producer adapters;
- Life Bridge v1 compatibility projection;
- explicit local deep-link transport;
- portable clipboard fallback;
- durable Drift inbox/outbox;
- same-mode idempotent delivery;
- concurrent inbox/outbox duplicate protection;
- legacy schema-v8 COPY-key compatibility;
- LINK isolation from legacy COPY dedupe;
- malformed/untrusted package normalization to `FormatException`;
- contract validation before durable persistence;
- safe media metadata with no private local URI crossing the bridge.

Evidence:

- hardening PR #5;
- CI run `37023549635`: GREEN;
- tested PR head `25578cade1f9dd32712d495b13caaf2ead9e8ea7`;
- squash merge on `main`: `77e6b11342e6b81ea9e5ecc0d9b731b4dc90a4c5`.

CodeRabbit was rate-limited/unavailable during this cycle and is NON-BLOCKING
under Master Prompt v21. The technical verdict is based on deterministic CI,
tests, builds and code inspection.

## NEXT — Anna's Diary consumer

Anna's Diary must now consume the frozen Shared Ecosystem Core v1 contract
without copying Wonderlog's private domain model or database.

Required next work:

1. register `annasdiary://ecosystem/import`;
2. decode and validate `EcosystemTransferPackage v1`;
3. enforce `targetApp == annas_diary`;
4. deduplicate by `<bridgeId>:<revision>:<copy|link>`;
5. preserve provenance;
6. materialize COPY and LINK with distinct destination semantics;
7. run the shared Golden contract vectors;
8. verify Wonderlog -> Anna and Anna -> Wonderlog round-trips.

Only after those gates pass may
`GOLDEN_ECOSYSTEM_BRIDGE_CONTRACT_v1_DRAFT.txt` be promoted from CANDIDATE
toward COPY-READY / certified reuse.

## LATER — Wonderlog production cutover

Still separate from E1 handoff readiness:

- remaining Journey/Memory/Album parity;
- Capture/Keepsakes parity;
- Smart Journey parity;
- Map Memories parity;
- Rediscover/Replay parity;
- Premium/RevenueCat parity;
- cloud backup/sync parity;
- real-device legacy Room -> Drift migration validation;
- macOS/iOS build gate;
- final Android/iOS/Web production certification.
