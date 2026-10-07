# MAXI STEP 27 — Release Hardening

Date: 2026-10-07

Baseline:
- `main @ 8f2fbd0181dbf42b88c9a402ede5768e0abb7de2`
- branch: `maxi-27-release-hardening`
- PR: #19
- final PR head: validated by the PR checks attached to the exact merged candidate SHA

Governance:
- Master Prompt v21 SLIM;
- Golden Release Reality & Physical Validation;
- Golden Backup & Recovery;
- Golden AppLab QA & Certification Adapter;
- Golden Provenance & Reuse Ledger.

## Implemented

### Localization release gate
- completed the 48 missing user-facing messages in each of IT/ES/FR/DE/PT;
- added `tool/check_localizations.py`;
- the gate requires exact message-key parity with EN;
- declared ICU placeholders must remain present;
- Flutter `gen-l10n` remains the syntax authority.

### Release version and Android update continuity
- moved from bootstrap `0.1.0+1` to `0.9.0+27`;
- added `tool/check_release_version.py`;
- CI rejects malformed/zero build numbers and the stale bootstrap version;
- the canonical donor contract proves legacy Android `versionCode = 1`;
- the Flutter build number `27` must remain strictly greater than the donor
  versionCode before a cutover artifact can be accepted.

### Android artifact size / ABI split
The verification lane now builds split release APKs instead of a universal APK.

PR run `37586623025`:
- armeabi-v7a: 33.0 MB;
- arm64-v8a: 37.8 MB;
- x86_64: 39.7 MB;
- AAB: 82.7 MB.

The AAB remains the Play-oriented packaging format. The ordinary CI artifacts
are explicitly labelled verification artifacts and are not claimed as
store-signed production releases.

### Production Android signing lane
Added `.github/workflows/android-production-release.yml`.

Contract:
- manual dispatch only;
- `main` only;
- preserves the legacy Android applicationId
  `com.aistudio.wanderlogmemories.pqrzmx` so an installed legacy app can be
  updated in place;
- requires keystore/password/alias secrets plus
  `ANDROID_EXPECTED_SIGNER_SHA256`;
- materializes keystore/key.properties only inside the runner;
- builds split APKs + AAB;
- verifies the APK certificate and requires its SHA-256 fingerprint to equal
  the trusted legacy signer fingerprint;
- rejects an unsigned AAB rather than trusting jarsigner exit status alone;
- records source SHA, version, package ID, workflow run, hashes and signing
  evidence;
- deletes materialized signing files in an always-run cleanup step.

No keystore/password is committed. The generated Android Gradle project uses
release signing only when `key.properties` exists; ordinary CI keeps its
non-store verification identity.

Status at PR gate:
- signing path: IMPLEMENTED;
- persistent production signing execution: NOT VERIFIED until run from
  `main` with real repository secrets.

### Stable Web deployment lane
Added `.github/workflows/web-preview.yml`.

Contract:
- build on `main`;
- GitHub Pages artifact + exact deploy action;
- repository base-href;
- optional Supabase build-time configuration from secrets;
- no claim that Web certifies native-only capabilities.

Status at PR gate:
- Web release compile: PASS;
- Pages workflow: IMPLEMENTED;
- stable deployed URL: NOT VERIFIED until the post-merge Pages run succeeds.

### Apple build gate
Added `.github/workflows/apple-build.yml` on `macos-latest`.

PR run `37586623232`:
- iOS release `--no-codesign`: PASS;
- `Runner.app`: 52.8 MB;
- macOS release compile: PASS;
- `wonderlog.app`: 92.0 MB;
- Apple evidence artifacts uploaded.

This proves Apple compilation, not App Store signing/distribution.

### Room v6 -> Drift v9 hardening
Added a pre-open migration safety snapshot for the real Android legacy DB path.

The donor ZIP is now an executable CI contract. It proves:
- legacy applicationId: `com.aistudio.wanderlogmemories.pqrzmx`;
- legacy versionCode: `1`;
- database name: `wanderlog-memories-db`;
- Room schema version: `6`;
- Room `exportSchema = false`;
- the exact nine v6 table names;
- legacy tags converter separator: `||`.

Before Wonderlog opens the detected legacy database through Drift:
1. its `PRAGMA user_version` is read;
2. future schemas fail closed;
3. v4/v5/v7/v8 and any other uncertified pre-v9 baselines fail closed;
4. only the canonical Room v6 baseline enters the safety-snapshot and
   normalization path;
5. DB + present WAL/SHM sidecars are copied into private migration backup
   storage;
6. SHA-256 + size metadata is recorded and re-verified;
7. source mutation during snapshot creation fails closed;
8. an existing/tampered snapshot fails verification;
9. Room v6 column normalization runs transactionally and is retry-safe;
10. schema v9 does not create another migration snapshot or normalization on
    later starts.

Wonderlog keeps the established Flutter/Drift v9 physical schema in snake_case,
so existing Flutter v9 databases remain reopenable. Only the certified Room v6
cutover path runs `LegacyRoomSchemaNormalizer`: after the verified safety
snapshot it transactionally and idempotently renames the canonical Room
camelCase columns to their Drift snake_case equivalents while leaving
`user_version = 6`. Drift then performs the existing v6 -> v9 migration.

The deterministic migration fixture is created directly from the canonical
Room v6 Kotlin entity contract rather than by downgrading a Drift v9 database.
It covers all nine legacy tables, camelCase-to-snake_case normalization, the
`||` tag converter, relationships, foreign keys and post-v9 unassigned
Memories. A separate regression test reopens an existing Flutter v9 snake_case
database to prevent the Room compatibility bridge from changing that contract.

`tool/legacy_room_v6_drill.dart`:
- accepts only a v6 input;
- requires all nine canonical tables;
- creates a verified safety snapshot;
- migrates only a working copy;
- compares deterministic pre/post row counts and content hashes;
- verifies FK integrity;
- leaves the supplied source file unchanged.

PR CI:
- Room-v6-shaped fixture: PASS;
- safety snapshot copy/hash/reuse/tamper tests: PASS.

Release boundary:
- real user Room v6 DB copy drill: NOT VERIFIED;
- physical in-place upgrade on an Android device: NOT VERIFIED.

## Deterministic evidence

The final PR gate must be read from the GitHub checks attached to the exact PR
head; the workflow evidence itself records `GITHUB_SHA` in each artifact.

Required green evidence:
- canonical donor-contract gate;
- release-version gate;
- zero-untranslated localization gate;
- Flutter localization generation;
- Drift generation;
- Flutter analyze;
- full Flutter test suite, including canonical Room v6 -> Drift v9 migration;
- Web release build;
- Android split release APKs;
- Android AAB;
- Android/Web evidence artifact upload;
- iOS release `--no-codesign` build;
- macOS release compile;
- Apple evidence upload.

Earlier validated Step 27 builds demonstrated approximate artifact sizes of
33.0 MB (armeabi-v7a), 37.8 MB (arm64-v8a), 39.7 MB (x86_64), 82.7 MB (AAB),
52.8 MB (unsigned iOS Runner.app) and 92.0 MB (macOS app). Final artifact
identity is determined by the exact final PR/main SHA, not by those historical
size observations.

## Evidence ladder status

- IMPLEMENTED: PASS for Step 27 code/process scope.
- STATICALLY CHECKED: PASS.
- TESTED: PASS for deterministic test scope.
- CI GREEN: PASS only when all final PR checks are green on the exact final SHA.
- ARTIFACT BUILT: PASS only for artifacts emitted by that exact successful
  final SHA.
- TRUSTED RUNTIME VERIFIED: NOT VERIFIED for this Step 27 artifact set.
- PHYSICAL DEVICE VERIFIED: NOT VERIFIED for real Room-v6 cutover and the new
  release artifact set.
- DISTRIBUTION VERIFIED: NOT VERIFIED at PR stage.
- STORE READY: NOT VERIFIED.
- PRODUCTION RELEASED: NO.

## Explicit remaining blockers

Step 27 does not close:
- real legacy Room v6 database/device migration drill;
- Play Internal Testing / App Store distribution;
- production RevenueCat/store configuration;
- persistent Android signing evidence until the production lane runs;
- stable Pages URL until the post-merge deployment succeeds;
- provider-configured + physical offline-map drill;
- any capability whose Golden matrix still requires physical validation.

## Verdict

**MAXI STEP 27 implementation: CI-GREEN / ARTIFACT-BUILT on the validated PR
head.**

**Wonderlog full product: NOT CERTIFIED for production cutover.**

No higher evidence level is inferred from CI compilation.
