# MAXI STEP 27 — Release Hardening

Date: 2026-10-07

Baseline:
- `main @ 8f2fbd0181dbf42b88c9a402ede5768e0abb7de2`
- branch: `maxi-27-release-hardening`
- PR: #19
- validated PR head: `d56b121fe8328d1859a9d1d03321ddb8f3b23a5d`

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

### Release version
- moved from bootstrap `0.1.0+1` to `0.9.0+27`;
- added `tool/check_release_version.py`;
- CI rejects malformed/zero build numbers and the stale bootstrap version.

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
- requires the four signing secrets;
- materializes keystore/key.properties only inside the runner;
- builds split APKs + AAB;
- verifies APK certificate and AAB signature;
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

Before Wonderlog opens `wanderlog-memories-db` through Drift:
1. the DB is detected;
2. DB + present WAL/SHM sidecars are copied into private migration backup
   storage;
3. SHA-256 + size metadata is recorded in a manifest;
4. copied bytes are re-verified;
5. a source that changes during snapshot creation fails closed;
6. an existing/tampered snapshot fails verification;
7. only after verified snapshot completion may Drift open the original legacy
   database.

Also added:
- deterministic Room-v6-shaped -> Drift-v9 fixture;
- legacy Room tag converter coverage;
- FK integrity check;
- post-v9 unassigned Memory acceptance;
- `tool/legacy_room_v6_drill.dart`, which migrates only a working copy derived
  from the verified snapshot and compares preserved table row counts/content
  hashes.

PR CI:
- Room-v6-shaped fixture: PASS;
- safety snapshot copy/hash/reuse/tamper tests: PASS.

Release boundary:
- real user Room v6 DB copy drill: NOT VERIFIED;
- physical in-place upgrade on an Android device: NOT VERIFIED.

## Deterministic evidence

Flutter Foundation run `37586623025` on
`d56b121fe8328d1859a9d1d03321ddb8f3b23a5d`:
- release-version gate: PASS;
- zero-untranslated localization gate: PASS;
- Flutter localization generation: PASS;
- Drift generation: PASS;
- Flutter analyze: PASS;
- 112 tests: PASS;
- Web release build: PASS;
- Android split release APKs: PASS;
- Android AAB: PASS;
- artifact preparation/upload: PASS.

Apple Build Gate run `37586623232` on the same source SHA:
- generated Apple platforms: PASS;
- iOS release no-codesign build: PASS;
- macOS release build: PASS;
- evidence packaging/upload: PASS.

## Evidence ladder status

- IMPLEMENTED: PASS for Step 27 code/process scope.
- STATICALLY CHECKED: PASS.
- TESTED: PASS for deterministic test scope.
- CI GREEN: PASS on the validated PR head.
- ARTIFACT BUILT: PASS for Web, split Android, AAB, unsigned iOS and macOS
  compile artifacts.
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
