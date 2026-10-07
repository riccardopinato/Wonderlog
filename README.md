# Wonderlog

Wonderlog is currently migrating to Flutter as its cross-platform baseline.

## Current execution state

The Flutter implementation under `flutter/` is the active development baseline.
The former Kotlin/Compose implementation remains a donor/reference until the
remaining production-cutover parity gates are closed.

### Shared Ecosystem Core / Life Bridge v1

The Wonderlog producer side is now a **stable handoff baseline** for the first
Anna's Diary integration:

- Shared Ecosystem Core v1 contract is implemented;
- Journey and Memory producer adapters are implemented;
- Life Bridge v1 compatibility projection is implemented;
- COPY and LINK remain distinct durable deliveries;
- inbox/outbox persistence is durable and concurrency-safe;
- legacy schema-v8 COPY idempotency remains compatible without suppressing LINK;
- malformed local-transfer packages fail closed as `FormatException`;
- private source-local media URIs are not transported;
- Anna's Diary deep-link target and portable clipboard fallback are defined.

Hardening PR #5 passed the complete Flutter CI gate on head commit
`25578cade1f9dd32712d495b13caaf2ead9e8ea7` and was squash-merged to `main`
as `77e6b11342e6b81ea9e5ecc0d9b731b4dc90a4c5`.

Shared Ecosystem Core v1 is now **CERTIFIED GOLDEN** for the physically tested
Android Wonderlog ↔ Anna's Diary scope (Xiaomi Redmi Note 10 Pro / Android 13).

MAXI STEP E2 is also merged: Wonderlog now has a durable Ecosystem Inbox,
history, explicit COPY/LINK presentation and the four user-controlled inbound
destinations (existing Journey, new Journey, unassigned Memory, ignore/archive).

The complete Wonderlog product is not production-certified yet. See the deep
post-E2 audit for the remaining blockers.

### Step 23 parity / dead-code audit

The post-E2 Flutter parity audit is complete. It removed one proven duplicate
runtime implementation (`DriftJourneyRepository`) and explicitly keeps cloud,
offline-map, migration and ecosystem modules that are incomplete or unwired but
still part of the approved cutover architecture. Full Kotlin -> Flutter product
parity is **not** claimed.

MAXI STEP 23A E2 Hardening is complete: E2 materialization is
transactional/exactly-once, E2 Premium counting is scoped correctly,
the deterministic Drift v8 -> v9 fixture is in CI and all four Inbox actions
have widget coverage.

MAXI STEP 23B Core Functional Repair is also complete at deterministic CI
level. Journey/Memory/Album now expose real media, first-class Memories and
Unassigned Memories, Keepsake open/share/export/rename/delete, Journey
edit/archive/restore/delete, Memory reassignment/delete and corrected
Rediscover/Replay photo linkage.

MAXI STEP 24 Premium Truth & Entitlement Unification is complete at
deterministic CI level. Wonderlog now uses one canonical Premium policy across
Journey/Memory creation, reassignment, Album, Capture, Smart Journey and the
Ecosystem Inbox. RevenueCat CustomerInfo remains the entitlement truth; the
current paywall advertises only shipped Premium capabilities.

MAXI STEP 25 Cloud Runtime Completion is implemented: Wonderlog now has
real local-first mutation queueing, authenticated + Premium manual Sync Now /
Restore, merge conflict protection, private-photo cloud restore, account-owner
binding and a provisioned Supabase backend with RLS and a private Storage
bucket. Cloud Backup is again a truthful shipped Premium capability; automatic
background scheduling remains deliberately disabled until its own
certification.

MAXI STEP 26 Maps / Offline Completion is implemented at runtime level:
Journey maps use MapLibre, the chronological Replay trace is no longer
misrepresented as routing, optional OSRM-compatible road routing is isolated
behind explicit configuration, Nominatim follows the selected/device locale,
and Android/iOS have a real provider-gated MapLibre offline-region engine.
Web remains explicitly online-only.

Production offline downloads still require an offline-authorized style/provider
and a physical native drill; Wonderlog does not bulk-download the standard OSM
tile service.

The next repair gate is **MAXI STEP 27 Release Hardening**.

See `docs/STEP_23_FLUTTER_PARITY_DEAD_CODE_AUDIT.md`,
`docs/STEP_23A_E2_HARDENING.md`,
`docs/STEP_23B_CORE_FUNCTIONAL_REPAIR.md`,
`docs/STEP_24_PREMIUM_TRUTH.md`,
`docs/STEP_25_CLOUD_RUNTIME_COMPLETION.md` and
`docs/STEP_26_MAPS_OFFLINE_COMPLETION.md`.

See:

- `flutter/README.md`
- `docs/ECOSYSTEM_E1_ANNA_HANDOFF.txt`
- `docs/GOLDEN_ECOSYSTEM_BRIDGE_CONTRACT_v1_DRAFT.txt`
- `ROADMAP.md`
- `docs/AUDIT_2026-10-06.md`
