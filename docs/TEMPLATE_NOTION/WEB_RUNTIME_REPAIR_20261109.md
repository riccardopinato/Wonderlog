# Web repair — Drift SQLite runtime missing on GitHub Pages

**Date:** 2026-11-09. **Baseline:** `main@f045588dd5dbd668541fec380f184f3ebcd8bb6f`. Factory Core `d4ed1185d36d419228fba6b57a979cde308bd321`.

## Confirmed source defect

The former `.github/workflows/web-preview.yml` generated a clean Flutter `web/` skeleton and uploaded `flutter/build/web` without `sqlite3.wasm` and `drift_worker.js`. The runtime `flutter/lib/core/database/database_connection_web.dart` created `driftDatabase(name: ...)` without `DriftWebOptions`. Flutter analyze + static Pages deploy alone did not detect this. Drift's official browser setup requires both binary assets for the web database.

**Source root cause confirmed; exact user browser error remains NOT VERIFIED**, since the public site could not be opened from this chat's HTTP inspection surface. The missing assets are a definite packaging defect, not proof that every reported symptom is explained by it.

## Fix

1. The platform-specific Web connection explicitly references `sqlite3.wasm` and `drift_worker.js` relative to the app's Pages base path `/Wonderlog/`.
2. The resolved Drift `2.31.0` and SQLite `2.9.4` dependencies are pinned to preserve compatibility with the upstream release binaries; native app model/DB migrations remain unchanged.
3. The existing Web Pages workflow downloads those two files **after** `flutter create` regenerates `web/`, then fails closed if either size or SHA-256 does not match the original release. It also fails closed if `build/web` does not retain the files, Flutter bootstrap or `/Wonderlog/` base href.
4. A headless Chrome smoke gate serves the **compiled release artifact** at the same `/Wonderlog/` subpath and checks that the app's `flutter-view` boots without uncaught browser JavaScript exceptions; the test uses no real account or personal data.
5. After deployment a separate `verify-live` GitHub job checks actual public `index.html`, `sqlite3.wasm` and `drift_worker.js` responses (correct SHA-256) at the GitHub Pages URL, with bounded retries. A green deployment without public HTTP verification is not accepted as successful distribution.
6. No Supabase keys, OAuth rules, RevenueCat, backend, storage migrations or native signing are changed.
5. Upstream assets (exact version, digest):
   - `simolus3/drift/releases/tag/drift-2.31.0` — `drift_worker.js`, SHA-256 `f0a9b87085f732fd7b6ee7eb34d3858c556f05d221eb1febfc443649cd365752`.
   - `simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4` — `sqlite3.wasm`, SHA-256 `922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117`.
   
Binary assets are fetched at build time and verified; no binary file needs to be stored in Git and no user secrets are present in the repo.

## Gates and manual test

- On PR, run `verify`, `apple-build`, `legacy-contract` to protect native code; Web Pages workflow only deploys on a successful main push (or manual dispatch), so **merging is not equivalent to successful Web distribution**.
- On merge, check `Wonderlog Stable Web Preview`: verified assets, `flutter build web`, artifact upload and Pages deploy all PASS on **exact main SHA**. Then inspect the live path `https://riccardopinato.github.io/Wonderlog/`.
- Browser network verification: `/Wonderlog/sqlite3.wasm` returns HTTP 200 and MIME `application/wasm`; `/Wonderlog/drift_worker.js` returns 200 JavaScript; assets must not be rewritten to HTML/404.
- Test in an **isolated, disposable profile**: open app → onboarding → create a synthetic Journey → reload → reopen Journey → validate persistence and Notes/media locally. Do **not** clear site storage, unregister service workers indiscriminately, or delete real user data.
- OAuth callback and cloud backup on real accounts remain separate device/consent QA. Physical test, browser HTTP content and user-experienced recovery = **NOT VERIFIED** until performed.
