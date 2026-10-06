# MAXI STEP 23A — E2 Hardening

Completed: 2026-10-06

Final PR: #12  
Final tested head: `8ce2a2214afa8f68c45448f7d7bf95ada161ef48`  
Squash merge: `1e04bde60a81c9c58ad8b96d693d0cdac5d9a0e0`

## Scope completed

- Ecosystem Inbox materialization is now transactional and exactly-once at the
  Drift store boundary.
- Domain writes and inbox resolution run inside the same database transaction,
  so a failed materialization rolls back instead of leaving orphan Journey or
  Memory data.
- Repeated/stale resolution attempts fail with
  `EcosystemInboxAlreadyResolvedException`.
- The E2 item UI has a per-item busy lock so the four materialization actions
  cannot be repeatedly fired while an operation is running.
- E2 Memory limits now use the correct scope:
  - existing Journey -> Memories in that Journey;
  - new Journey -> new Journey starts with zero Memories;
  - unassigned Memory -> separate unassigned-Memory bucket.
- The Journey free limit remains enforced inside the atomic create-Journey flow.
- A deterministic Drift v8 -> v9 existing-data migration fixture verifies
  preservation of Journey, Memory, photo link, attachment and ecosystem inbox
  data, then verifies that v9 accepts true unassigned Memories and has no
  foreign-key violations.
- Widget/UI coverage now exercises all four E2 actions:
  add to existing Journey, create new Journey, save unassigned Memory,
  ignore/archive.
- Concurrency and rollback tests cover exactly-once behavior.

## Evidence

GitHub Actions run #160 on the final PR head passed:
- Flutter analyze;
- unit/widget tests;
- Web release build;
- Android release APK;
- Android AAB;
- artifact preparation/upload.

CodeRabbit advisory status was green.

## Deliberate boundaries

This step hardens **E2**. It does not complete the wider product-wide Premium
unification. Normal Journey/Memory creation paths outside E2 still need the
canonical entitlement policy planned for MAXI STEP 24.

The deterministic v8 -> v9 migration fixture is stronger CI evidence, but it
does not replace the still-required physical Room v6 -> Drift v9 upgrade drill
on real legacy user data.

Wonderlog as a whole remains NOT CERTIFIED for production cutover.
