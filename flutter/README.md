# Wonderlog Flutter

This directory is the cross-platform migration target for Wonderlog.

## Current role

Flutter is now the repository baseline for Wonderlog. The former
Kotlin/Compose implementation remains a donor/reference for parity checks and
regression analysis during the production cutover.

This Flutter foundation already provides:

- Material 3 light/dark/system theming;
- EN/IT/ES/FR/DE/PT localization foundation;
- local-first Drift schema mirroring the current Journey/Memory/Album model;
- functional local Journey creation and listing;
- optional Supabase identity with Google OAuth and email/password fallback;
- profile language/theme preferences;
- Shared Ecosystem Core v1 with stable bridge identity, provenance,
  COPY/LINK semantics, local explicit transport, portable fallback and
  durable inbox/outbox for Anna's Diary / Notes / TrailPath interoperability;
- Android, iOS and Web platform generation in CI.

## Safety rule

Do not replace the production Android application with this build until the
legacy data migration/import path and feature-parity gate are complete.

On Android, the cutover code reuses the legacy production Room database when
present and migrates it non-destructively through Drift. Fresh installs and
other platforms use the Flutter-managed database path.

## Local setup

1. Install the Flutter stable version used by CI.
2. From this directory generate platforms:

   flutter create --project-name wonderlog --org com.riccardopinato --platforms=android,ios,web /tmp/wonderlog_platform
   cp -R /tmp/wonderlog_platform/android .
   cp -R /tmp/wonderlog_platform/ios .
   cp -R /tmp/wonderlog_platform/web .
   python3 tool/prepare_generated_platforms.py

3. Run:

   flutter pub get
   flutter gen-l10n
   dart run build_runner build --delete-conflicting-outputs
   flutter analyze
   flutter test

Cloud auth is optional. Configure it with dart-defines only when needed:

- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY
- WONDERLOG_AUTH_REDIRECT
- WONDERLOG_WEB_AUTH_REDIRECT

No secret belongs in the repository.


## CI gate

Every pull request touching the Flutter migration must pass localization/code
generation, analyze, unit tests, Web release build, Android release APK and AAB
build before it can be considered for merge. The current migration branch has
passed this complete CI gate.


## Ecosystem E1

The first ecosystem integration layer is provider-independent.

- `bridgeId` is stable for the canonical owner/entity.
- `revision` plus COPY/LINK mode forms the idempotent delivery identity.
- provenance and fallback are part of the common wire contract.
- private media URIs never cross apps; media uses explicit handoff metadata.
- local transport uses target deep links with a machine-readable clipboard
  fallback.
- cloud transport remains optional and separate from the data contract.
- no app reads another app's private database.

The candidate Golden contract is documented in
`docs/GOLDEN_ECOSYSTEM_BRIDGE_CONTRACT_v1_DRAFT.txt`.
It is intentionally not promoted to COPY-READY until Anna's Diary implements
and certifies the consumer side.
