# MAXI STEP 23B — Core Functional Repair

Completed: 2026-10-06

## Scope completed

### Real photo/media UX
- private content-addressed media assets now render as real images;
- Journey Album renders real thumbnails;
- Memory surfaces render linked photos;
- full-screen photo viewer supports zoom, favorite, Journey cover, Memory unlink and delete;
- broken/missing media has an explicit fallback;
- delete cleanup removes the private blob only after the final durable reference disappears.

### Keepsakes / documents
- Capture/Keepsake import now copies supported files into Wonderlog private media storage;
- supported Keepsakes: PDF, JPEG/JPG, PNG and WebP;
- Memory Detail supports open, share, export, rename and delete;
- native and Web file-action boundaries are separate and testable;
- file-not-found/action failures are surfaced without corrupting local state.

### Journey / Memory / Photo lifecycle
- Journey edit flow;
- archive / restore;
- active and archived Journey surfaces;
- Journey delete with cascade impact preview;
- Memory delete;
- Memory move to an existing Journey or back to unassigned;
- Photo favorite / cover / unlink / delete;
- reference-aware media cleanup after Journey, Memory, Photo and Keepsake deletion.

### First-class Memories surface
- Memories is now a primary navigation destination;
- global All Memories view;
- Unassigned Memories filter;
- unassigned Memories can later be assigned to a Journey;
- real linked media is visible from this surface.

### Rediscover / Replay correctness
- Rediscover no longer guesses a Memory photo from any photo in the same Journey;
- Memory cards use explicit Memory ↔ Photo links;
- Replay Memory slides receive the real linked photo URIs.

## Deterministic evidence

PR #14 validation head before documentation:
`8b40b92cdf182bed50f4cd4d873855d64e4787aa`

GitHub Actions run:
`37483068653`

Passed:
- Flutter analyze;
- 91 unit/widget tests;
- Web release build;
- Android release APK;
- Android AAB;
- artifact preparation/upload.

Observed artifact sizes in that run:
- universal APK: about 74.1 MB;
- AAB: about 70.4 MB.

## Merge / main evidence

PR #14 squash merge:
`5b3a253d7355f1af92fbd691663efa0e20fdbbbb`

Post-merge main GitHub Actions run:
`37485260181`

Post-merge result:
- Flutter analyze: PASS;
- 91 tests: PASS;
- Web release: PASS;
- Android release APK: PASS;
- Android AAB: PASS;
- artifact preparation/upload: PASS.

Post-merge artifact sizes:
- universal APK: about 74.1 MB;
- AAB: about 70.4 MB.

## Deliberate boundaries

23B does **not** claim full production certification.

Still separate:
- product-wide Premium/RevenueCat truth and entitlement unification;
- cloud backup/sync runtime;
- true offline maps;
- OSM locale correction;
- N+1 Memory/media query optimization;
- indexed/debounced global search;
- zero untranslated-key gate;
- lightweight ARM64/split test APK;
- stable Web deployment;
- iOS build/signing;
- physical Room v6 -> Drift v9 legacy-data drill.

The 48 pre-existing untranslated messages for each non-English locale remain a
known release-hardening issue. New 23B strings were added for all supported
locales and did not increase that debt.

## Verdict

MAXI STEP 23B core functional scope: MERGED / MAIN CI-GREEN.

Wonderlog full product: NOT CERTIFIED for production cutover.
