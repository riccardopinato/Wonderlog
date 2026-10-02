# GOLDEN ECOSYSTEM BRIDGE FLUTTER v1 — CANDIDATE

Status: **DRAFT/CANDIDATE**  
Scope: Wonderlog Flutter Shared Ecosystem Core v1  
Source class: internal implementation / Golden-candidate extraction  
External OSS code copied: **none**

## Master Prompt v20 hierarchy

This candidate follows the project source hierarchy:

1. Product Bible / Master / internal Golden Components;
2. real implementation already present in Wonderlog and Anna's Diary;
3. certified internal donors;
4. approved OSS repositories;
5. external documentation/tools;
6. new code only where the previous layers do not provide the required contract.

The E1 work therefore extends the existing Wonderlog EcosystemEnvelope,
Drift inbox/outbox and Anna Life Bridge adapter instead of introducing a
parallel interoperability system.

## Contract invariants

- every app keeps its own canonical database and domain model;
- cross-app transfer is explicit and versioned;
- COPY and LINK are distinct transfer intents;
- bridgeId is deterministic from source app, entity type, entity id and
  revision;
- idempotencyKey remains stable for the same canonical source revision;
- provenance always identifies the canonical owner and revision;
- private envelopes fail closed;
- target capability negotiation fails closed;
- local media references never cross the transport boundary;
- safe media metadata may cross the boundary;
- fallback text and encoded fallback payload are available when direct
  deep-link handoff is unavailable;
- inbox/outbox persist independently of UI lifecycle;
- no app reads another app database;
- no shared database, indiscriminate sync or mandatory cross-app account id;
- cloud transport is a separate optional adapter and is not part of E1.

## Local transport v1

The local transport produces a versioned EcosystemHandoffPacket.

A handoff may expose:

- a target-specific deep-link URI carrying a base64url encoded packet;
- the same encoded packet as explicit clipboard/share fallback;
- plain-text fallback content for unsupported destinations.

Receiving the packet only persists it in the destination inbox. Materializing
it into destination domain entities remains a destination-owned, explicit
import step.

## Compatibility model

Each destination registers:

- accepted entity types;
- supported COPY/LINK modes;
- supported capabilities;
- optional local import scheme.

The sender derives required capabilities from the actual envelope and rejects
the handoff when the destination cannot satisfy them.

## Certification evidence required before GOLDEN

This document must remain CANDIDATE until all of the following pass:

1. Wonderlog unit/contract tests;
2. Web release build;
3. Android release APK/AAB build and size gate;
4. AppLab trusted runtime;
5. Anna's Diary adapter consumes the same packet contract;
6. real Wonderlog -> Anna COPY round-trip;
7. real Wonderlog -> Anna LINK round-trip;
8. duplicate delivery / app-closed / offline-retry evidence;
9. media privacy validation;
10. CodeRabbit review with no unresolved blocking finding.

Only after those gates may the component be promoted to
GOLDEN_ECOSYSTEM_BRIDGE_FLUTTER_v1.
