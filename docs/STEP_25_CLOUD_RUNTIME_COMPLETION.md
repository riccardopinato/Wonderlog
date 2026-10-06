# MAXI STEP 25 — Cloud Runtime Completion

Date: 2026-10-07

Baseline: `main @ fef8988d23413d1be2e3bb8544371c4710a96a44`

PR: #17 — `MAXI STEP 25: Cloud Runtime Completion`

## Outcome

Step 25 converts the pre-existing cloud domain/data code into a real
production runtime path and provisions the matching Supabase backend.

Wonderlog remains local-first. Local Journey/Memory/Album writes succeed without
requiring a network request; cloud mutations are queued durably and are sent
only through explicit authenticated + Premium cloud operations.

## Production runtime wiring

`main.dart` now constructs, when Supabase is configured:

- `SupabaseCloudProvider`;
- `DriftSyncQueueStore`;
- `DriftCloudLocalDataSource`;
- `DriftCloudRelationshipSource`;
- `CloudSyncRepository`;
- `CloudRestoreRepository`;
- `MediaAssetRestoredPhotoStorage`;
- `SharedPreferencesCloudBackupSettingsRepository`;
- `CloudRuntimeController`.

`CloudAwareWonderlogRepository` wraps the canonical
`DriftWonderlogRepository` so product mutations automatically update local
sync state and enqueue cloud work without replacing the local-first repository
contract.

## Manual cloud UX

Profile exposes a first-class Cloud Backup screen with:

- account status;
- Premium status;
- pending operation count;
- last successful backup timestamp;
- include-photos setting;
- manual `Sync now`;
- explicit `Restore from cloud` confirmation;
- restore progress;
- sync/restore result summaries;
- account/Premium/busy failure handling.

Automatic background backup remains intentionally disabled in Step 25. Any
legacy persisted automatic setting is forced off at runtime. A scheduler can be
introduced only after this manual path has accumulated deterministic and
physical evidence.

## Queue and mutation correctness

Step 25 hardens the durable queue beyond the original implementation:

- Journey, Memory and Album writes are marked `PENDING_UPLOAD` before queueing;
- deletions use `PENDING_DELETE`;
- a delete collapses an older unsent upload for the same entity;
- deterministic cloud ids allow delete operations to survive local-row removal;
- queue draining handles more than one 25-item batch;
- a batch containing only failures stops instead of retry-looping indefinitely;
- failed items remain queued for an explicit later retry;
- photo upload opt-out pauses photo create/update operations but does not block
  remote photo deletions;
- Memory–Photo links are reconciled as a safe desired snapshot: desired links
  are upserted first, then only stale links are removed.

## Restore and conflict safety

`CloudRestoreRepository` is a production caller now.

The restore path:

- fetches Journeys, Memories, photos and Memory–Photo relationships;
- maps stable cloud/local identities;
- rebuilds private photo blobs through the app media store;
- uses `CloudMergeEngine` before applying cloud values;
- never silently overwrites an unsynced local edit;
- marks such rows `CONFLICT`;
- reports inserted/updated/skipped/conflict/failure counts.

Deterministic tests prove a newer cloud Journey does not overwrite an unsynced
local Journey.

## Account isolation

The local dataset is persistently bound to the first Supabase user that performs
an entitled cloud operation.

- Free/non-entitled attempts do not bind the dataset.
- The first authenticated Premium cloud action persists the owner id.
- A later different account is blocked with `accountMismatch`.

This prevents a device-level local database from being silently uploaded into a
second user's cloud namespace after account switching.

## Live Supabase backend

The shared Supabase project was provisioned without altering Anna's existing
application tables.

Applied migrations:

- `wonderlog_cloud_runtime_v1`;
- `wonderlog_cloud_fk_indexes_v1`.

Provisioned Wonderlog resources:

- `public.journeys`;
- `public.memories`;
- `public.album_photos`;
- `public.memory_photos`;
- private Storage bucket `wonderlog-photos`.

All four Wonderlog tables have RLS enabled. Authenticated SELECT/INSERT/UPDATE/
DELETE policies restrict rows to `auth.uid() = owner_id`. Storage policies
restrict private files to the owner and user-id path prefix.

A two-user RLS smoke drill passed:

1. owner A inserted and updated a synthetic Journey;
2. owner B could not read that row;
3. owner A deleted it;
4. cleanup verification returned zero smoke rows.

Supabase performance advisors initially reported four Wonderlog FK-index
findings; the second migration added covering indexes and cleared those
findings. Remaining advisor warnings are project-wide/pre-existing
(`pg_net` in `public`, leaked-password protection disabled) rather than
Wonderlog schema defects.

## Premium truth

Cloud Backup is now a shipped Premium capability:

- `SubscriptionConfig.premiumCloudBackup = true`;
- Free remains blocked;
- Premium paywall includes secure cloud backup/restore;
- Offline Maps, Premium Themes and Advanced Statistics remain unavailable.

RevenueCat CustomerInfo remains the entitlement source of truth.

## Deliberate scope boundary

Cloud protection currently covers:

- Journeys;
- Memories assigned to a Journey;
- album photo metadata and private photo binaries;
- Memory–Photo relationships.

Unassigned Memories and Keepsakes remain local-only in this step. Their status is
stated explicitly in the Cloud Backup UI; they are not marketed as cloud
protected.

## Deterministic coverage

Step 25 adds/extends tests for:

- manual auth + Premium guard;
- automatic-backup guard separation;
- account owner binding and account swap rejection;
- multi-batch queue drain (>25 records);
- upload/delete queue compaction;
- deletion after local-row removal;
- include-photos opt-out while preserving remote deletes;
- restore reconstruction of Journey/Memory/Photo/relationship;
- restore conflict protection for unsynced local edits;
- Premium Cloud Backup availability truth.

## Delivery status

Validated final PR head:
- `cd23f06ee81d9fdd6c2f7811cda13b8892379684`;
- GitHub Actions run `37541980040`: PASS;
- Analyze: PASS;
- tests: PASS;
- Web release: PASS;
- Android release APK: PASS;
- Android AAB: PASS;
- Android artifact upload: PASS;
- Web artifact upload: PASS.

Background scheduling remains disabled by design. The next product block is
MAXI STEP 26 — Maps / Offline Completion.
