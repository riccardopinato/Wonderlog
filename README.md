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

This means **Wonderlog is ready to act as the producer/donor baseline for
Anna's Diary**. It does **not** mean the bridge is cross-app CERTIFIED yet:
final certification still requires the Anna consumer implementation and the
real Wonderlog <-> Anna contract round-trip.

See:

- `flutter/README.md`
- `docs/ECOSYSTEM_E1_ANNA_HANDOFF.txt`
- `docs/GOLDEN_ECOSYSTEM_BRIDGE_CONTRACT_v1_DRAFT.txt`
- `ROADMAP.md`
