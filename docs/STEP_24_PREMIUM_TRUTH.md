# MAXI STEP 24 — Premium Truth & Entitlement Unification

Date: 2026-10-06

Baseline: `main @ 5a3b164e0dc3e248e7245fa3b39be6502cfcf7b7`

Validated runtime head: `0b60f7dd5420fe72c6b489fffe85f41ca0e9de3c`

GitHub Actions run: `37495356564`

## Objective

Make Premium entitlement and plan-limit behavior a product-wide source of truth instead of a collection of independent UI gates.

## Canonical truth

`PremiumAccessPolicy` is the single runtime policy used by product flows. It derives paid access from `AppController.isPremium`, which in turn reflects the RevenueCat `CustomerInfo` entitlement named `premium`.

The RevenueCat offering/store remains the source of truth for sellable packages and prices. The application no longer hardcodes monthly/yearly/lifetime product identifiers.

## Plan limits

Free:
- 3 owned Journeys total; archived Journeys still count;
- 5 Memories per Journey;
- 5 unassigned Memories in a separate unassigned bucket;
- 5 photos per Journey.

Premium:
- Journey creation effectively unlimited;
- Memory creation effectively unlimited;
- up to 100 photos per Journey.

Existing data is never deleted or hidden after entitlement loss. Quotas prevent new creation/reassignment beyond the current plan; they do not make existing content inaccessible.

## Unified entry points

The canonical policy now covers:
- Home / Journeys standard Journey creation;
- standard Memory creation;
- Memory reassignment between Journey/unassigned buckets;
- Journey Album photo import;
- Capture Memory/photo creation;
- Smart Journey Journey/photo/Memory materialization;
- Ecosystem Inbox create Journey / add to Journey / save unassigned Memory;
- PDF export feature access.

Smart Journey performs entitlement evaluation before persistence so a Free-plan Memory overflow cannot leave a partially created Journey.

## Premium product truthfulness

Current Premium UI advertises only capabilities that are actually shipped:
- unlimited Journeys and Memories;
- extended Album capacity up to 100 photos per Journey;
- PDF Travel Book export.

Cloud Backup, Offline Maps, Premium Themes and Advanced Statistics remain unavailable capability flags until their corresponding runtime steps are completed. They are not treated as unlocked merely because the account has Premium.

Cloud runtime completion remains MAXI STEP 25. Real Offline Maps remains MAXI STEP 26.

## RevenueCat boundary

The stable entitlement id remains:

`premium`

Store API keys continue to be provided via environment defines. Production RevenueCat project/store configuration is intentionally not claimed by this step and must be completed only with the actual store setup.

Restore continues to use RevenueCat CustomerInfo as entitlement truth. SDK/cache behavior remains authoritative; Wonderlog does not create an independent local paid flag.

## Test evidence

Deterministic coverage includes:
- Free Journey quota counts archived Journeys;
- Memory quota is independent per Journey;
- unassigned Memories use their own 5-item bucket;
- Premium Journey/Memory creation is not constrained by Free limits;
- Premium Album remains capped at 100 photos per Journey;
- Smart Journey Memory batch allowance is deterministic;
- Premium cannot use unfinished Cloud Backup/Offline Maps merely by holding an entitlement;
- PDF export remains a shipped Premium capability.

CI run `37495356564`:
- localization generation: PASS;
- Drift generation: PASS;
- Flutter analyze: PASS;
- Flutter tests: PASS;
- Web release build: PASS;
- Android release APK: PASS;
- Android AAB: PASS;
- Android artifacts upload: PASS;
- Web artifact upload: PASS.

## Verdict

MAXI STEP 24 runtime implementation: **CI-GREEN**.

This step closes the product-wide Premium enforcement/truthfulness blocker. It does not claim Wonderlog production certification, cloud-runtime completion, real offline maps, production store configuration, release signing, stable Web deployment or legacy physical migration certification.
