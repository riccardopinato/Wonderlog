# Wonderlog Supabase backend

MAXI STEP 25 provisions Wonderlog cloud data on the shared Supabase project
`agenda-per-anna` while keeping Anna's existing tables untouched.

Deployed migrations:
- `wonderlog_cloud_runtime_v1`;
- `wonderlog_cloud_fk_indexes_v1`.

Wonderlog owns these isolated resources:
- `public.journeys`;
- `public.memories`;
- `public.album_photos`;
- `public.memory_photos`;
- private Storage bucket `wonderlog-photos`.

All four public tables have RLS enabled. Authenticated CRUD policies bind every
row to `auth.uid() = owner_id`. Storage policies restrict private objects to
the owning authenticated user and the first path segment is the user id.

A two-user RLS smoke drill was executed after provisioning:
- owner A inserted and updated a synthetic Journey;
- owner B could not see the row;
- owner A deleted the row;
- cleanup verification returned zero smoke rows.

Supabase advisors after the FK-index follow-up show no Wonderlog-specific
missing-FK-index warning. Remaining security warnings are project-wide and
pre-existing: `pg_net` is installed in `public`, and leaked-password
protection is disabled.

The client uses only the Supabase URL plus a publishable key. Never ship a
secret/service-role key.

When `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are configured,
Wonderlog cloud data is enabled by default. A special build can disable it with:

`--dart-define=WONDERLOG_CLOUD_DATA_ENABLED=false`

Current Step 25 cloud scope:
- Journeys;
- Memories assigned to a Journey;
- album photos and their private binary objects;
- Memory–Photo links.

Unassigned Memories and Keepsakes remain local-only and are deliberately not
advertised as cloud-protected.
