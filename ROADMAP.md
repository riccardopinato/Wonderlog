# Wonderlog Roadmap

Execution truth as of 2026-10-06.

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

## DONE — E1 Wonderlog ↔ Anna physical round-trip

Shared Ecosystem Core v1 has now been exercised across two real Android apps.

Physical observations completed on 2026-10-05:
- Wonderlog -> Anna COPY opens the Anna review/import flow and materializes once;
- repeated COPY is rejected as a duplicate;
- Wonderlog -> Anna LINK opens the Anna review/import flow and materializes once;
- repeated LINK is rejected as a duplicate;
- Anna -> Wonderlog opens Wonderlog through `wonderlog://ecosystem/import`;
- Wonderlog persists the Anna note in the durable ecosystem inbox;
- the received item is visible on Home without auto-creating a Journey or Memory.

The Android package-visibility defect caused by using `canLaunchUrl()` as a
custom-scheme preflight was fixed by attempting the external launch directly
and falling back only on an actual launch failure.

Golden status:
- Shared Ecosystem Core v1: CERTIFIED GOLDEN under Master Prompt v21;
- physical-device evidence completed on Xiaomi Redmi Note 10 Pro / Android 13;
- tested bidirectional Wonderlog ↔ Anna round-trip: PASS.

## DONE — MAXI STEP E2 Ecosystem UX Completion

Merged to main in PR #9 as `c6cff63b3db085af5a17ac87a10f96c0d8935c35`.

Implemented:
- real Ecosystem Inbox with pending/history tabs;
- durable resolution outcome;
- add to existing Journey;
- create new Journey;
- save as true unassigned Memory;
- ignore/archive;
- COPY/LINK distinction;
- LINK source reopen;
- connected-app detail for Anna's Diary;
- Home receipt routes into Inbox;
- Drift schema v9 for unassigned Memories and inbox outcomes.

PR gate:
- analyze PASS;
- tests PASS;
- Web release PASS;
- Android APK PASS;
- Android AAB PASS.

## NEXT — MAXI STEP 23A E2 Hardening

Deep audit 2026-10-06 identified these first repairs:
- atomic exactly-once inbox materialization;
- canonical Premium gate across every creation path;
- correct per-Journey vs unassigned Memory limit policy;
- deterministic v8 -> v9 migration fixture;
- full UI tests for all four E2 actions.

See `docs/AUDIT_2026-10-06.md`.

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
