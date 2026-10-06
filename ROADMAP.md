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

## DONE — MAXI STEP 23 Flutter Parity & Dead-Code Audit

Completed on the Flutter baseline after E2.

Outcome:
- current Flutter runtime/parity inventory documented;
- true dead code separated from planned-but-unwired infrastructure;
- duplicate `DriftJourneyRepository` removed;
- repository tests now exercise canonical `DriftWonderlogRepository`;
- Kotlin donor ZIP intentionally retained until production cutover parity and Room -> Drift evidence close;
- no claim of full product parity or production certification.
- final PR #11 head `3d3d6330fb98aa0f5497df62c49529f3b15f783e` passed analyze, unit tests, Web release build, Android release APK and Android AAB; CodeRabbit advisory was green.
- PR #11 was squash-merged to `main` as `18a5116880107abe08d6b776e14c154780bd83cc`.

Evidence:
- `docs/STEP_23_FLUTTER_PARITY_DEAD_CODE_AUDIT.md`.

## DONE — MAXI STEP 23A E2 Hardening

Completed in PR #12 and squash-merged to `main` as
`1e04bde60a81c9c58ad8b96d693d0cdac5d9a0e0`.

Completed:
- atomic exactly-once Ecosystem Inbox materialization inside a Drift transaction;
- rollback-safe domain writes and stale/concurrent action rejection;
- per-item UI busy lock;
- correct E2 Memory counting per Journey plus a separate unassigned bucket;
- Journey free-limit enforcement inside the atomic E2 create flow;
- deterministic v8 -> v9 existing-data migration fixture;
- UI tests for all four E2 Inbox actions;
- concurrency and rollback regression tests.

Final PR head `8ce2a2214afa8f68c45448f7d7bf95ada161ef48`
passed analyze, tests, Web release, Android release APK and Android AAB.
CodeRabbit advisory status was green.

The wider product-wide Premium creation policy is intentionally deferred to
MAXI STEP 24. Physical Room v6 -> Drift v9 migration certification is also
still required later.

Evidence:
- `docs/STEP_23A_E2_HARDENING.md`.

## DONE — MAXI STEP 23B Core Functional Repair

Completed in PR #14 and squash-merged to `main` as
`5b3a253d7355f1af92fbd691663efa0e20fdbbbb`.

Completed:
- real private-media rendering in Journey Album, Memory and Rediscover surfaces;
- full-screen photo viewer with favorite, cover, unlink and delete actions;
- reference-aware private media cleanup;
- private Keepsake import plus open/share/export/rename/delete;
- Journey edit/archive/restore/delete with cascade impact preview;
- active + archived Journey lists;
- Memory delete and Journey reassignment/unassignment;
- first-class Memories navigation with All / Unassigned filters;
- Rediscover and Replay now consume explicit Memory ↔ Photo links.

Deterministic gate on head `8b40b92cdf182bed50f4cd4d873855d64e4787aa`:
- analyze PASS;
- 91 tests PASS;
- Web release PASS;
- Android APK PASS;
- Android AAB PASS.

Post-merge integration gate:
- main run `37485260181`: PASS;
- analyze PASS;
- 91 tests PASS;
- Web release PASS;
- Android APK PASS;
- Android AAB PASS.

Evidence:
- `docs/STEP_23B_CORE_FUNCTIONAL_REPAIR.md`.

## DONE — MAXI STEP 24 Premium Truth & Entitlement Unification

Completed in PR #16.

Completed:
- one canonical `PremiumAccessPolicy` for product-wide plan decisions;
- entitlement truth derives from RevenueCat CustomerInfo through `AppController`;
- Free limits unified at 3 owned Journeys, 5 Memories per Journey, a separate 5-item unassigned Memory bucket and 5 photos per Journey;
- Premium Journey/Memory creation effectively unlimited, with 100 photos per Journey;
- archived Journeys count toward the Free ownership quota;
- standard Journey/Memory creation, reassignment, Album, Capture, Smart Journey and Ecosystem Inbox use the same policy;
- Smart Journey blocks Memory-overflow before persistence;
- PDF export uses the canonical feature gate;
- unfinished Cloud Backup / Offline Maps / Premium Themes / Advanced Statistics are not exposed as available Premium capabilities;
- RevenueCat offerings/store data remain the package/price truth; hardcoded product ids were removed.

Validated runtime head `0b60f7dd5420fe72c6b489fffe85f41ca0e9de3c`:
- GitHub Actions run `37495356564`: PASS;
- analyze PASS;
- tests PASS;
- Web release PASS;
- Android APK PASS;
- Android AAB PASS;
- artifact uploads PASS.

Evidence:
- `docs/STEP_24_PREMIUM_TRUTH.md`.

## NEXT — MAXI STEP 25 Cloud Runtime Completion

## LATER — Wonderlog production cutover

Still separate from E1 handoff readiness:

- remaining Journey/Memory/Album parity;
- Capture/Keepsakes parity;
- Smart Journey parity;
- Map Memories parity;
- Rediscover/Replay parity;
- production RevenueCat/store configuration;
- cloud backup/sync parity;
- real-device legacy Room -> Drift migration validation;
- macOS/iOS build gate;
- final Android/iOS/Web production certification.
