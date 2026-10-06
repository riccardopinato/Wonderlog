# Wonderlog Supabase backend contract

Step 25 wires the Flutter runtime to Supabase, but the connected Supabase account
currently exposes only a project named `agenda-per-anna`. The Wonderlog schema
must not be applied there by assumption.

`WONDERLOG_CLOUD_SCHEMA.sql` is therefore a reviewed bootstrap contract, not a
recorded Supabase migration. Apply it only after identifying the intended
Wonderlog backend project. Then run Supabase security/performance advisors and
a signed-in smoke test for Journey, Memory, photo upload/download, relationship
sync, delete and restore.

The client uses a publishable key only. Never ship a secret/service-role key.

Activation also requires the Flutter dart-define
`WONDERLOG_CLOUD_DATA_ENABLED=true`. `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` alone enable identity but do not opt the same
backend into Wonderlog data storage.

Current Step 25 cloud scope:
- Journeys;
- Memories assigned to a Journey;
- album photos and their private binary objects;
- Memory–Photo links.

Unassigned Memories and Keepsakes remain local-only and are deliberately not
advertised as cloud-protected.
