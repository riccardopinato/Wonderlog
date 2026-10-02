# Wonderlog Flutter

This directory is the cross-platform migration target for Wonderlog.

## Current role

The existing Kotlin/Compose application remains the functional donor and source
of implementation truth while feature parity is rebuilt in Flutter.

This Flutter foundation already provides:

- Material 3 light/dark/system theming;
- EN/IT/ES/FR/DE/PT localization foundation;
- local-first Drift schema mirroring the current Journey/Memory/Album model;
- functional local Journey creation and listing;
- optional Supabase identity with Google OAuth and email/password fallback;
- profile language/theme preferences;
- versioned EcosystemEnvelope contracts for future Anna's Diary / Notes /
  TrailPath interoperability;
- Android, iOS and Web platform generation in CI.

## Safety rule

Do not replace the production Android application with this build until the
legacy data migration/import path and feature-parity gate are complete.

The Flutter database intentionally uses a different database file during
migration development.

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
