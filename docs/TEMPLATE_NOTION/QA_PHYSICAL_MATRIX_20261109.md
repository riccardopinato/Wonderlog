# Template QA — Wonderlog Trip Planner

**Baseline:** `main@c238afd82ca93699d0e0d5d4e3e3a9a0d6d1d9ee` from PR #26, CI Flutter and Apple PASS, but initial Stable Web Preview deployment **FAILED** (GitHub Pages `syncing_files` timeout; build artifact passed). A single failed Pages deploy job has been retried against the same exact commit; record the second attempt result separately.

## Automated and code contract

- `flutter/test/trip_planner_template_test.dart` checks selected heading inclusion, no blank pseudo-headings and source-level location of confirmation/Premium recheck before `createJourney`.
- No secondary trip store, budget calculations, structured packing DB, route, booking or billing change.
- Exact-head `verify`, `apple-build`, `legacy-contract`, Web build and Pages deploy remain separate evidence gates.

## Manual acceptance — NOT VERIFIED

| ID | Execution | PASS criteria |
|---|---|---|
| W-01 | Start a normal Journey without template | Existing writer/path unchanged |
| W-02 | Enable Trip Planner, select one/both sections, cancel summary | Zero Journey records created |
| W-03 | Confirm one Journey with date interval | Exactly one Journey, editable plain-text description |
| W-04 | Empty title/destination or invalid date order | No write, invalid input blocked |
| W-05 | Free Journey cap reached before or after summary | Premium gate blocks new Journey; no false unlock |
| W-06 | Double tap save, simulate failure/retry | No duplicate or broken partially saved Journey |
| W-07 | Switch profile and restore backup in isolated environment | Ownership preserved; no cross-account leakage |
| W-08 | 320dp, 2× text and en/it/es/fr/de/pt locales | Responsive and fully localized, keyboard accessible |
| W-09 | Load `https://riccardopinato.github.io/Wonderlog/` after successful exact SHA Pages deploy | App assets load on nested Pages base path, correct source version and no broken redirect |

**Environment/device proof is missing** until a real session captures exact artifact identity, observed results and redacted evidence. GitHub Pages workflow green is not proof of offline/SSO or native package behavior.
