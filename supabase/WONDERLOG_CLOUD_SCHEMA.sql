-- Wonderlog Step 25 cloud schema contract.
-- Applied to the shared Supabase backend as migration
-- wonderlog_cloud_runtime_v1, followed by wonderlog_cloud_fk_indexes_v1.
-- Keep this file aligned with the deployed schema so a new backend can be
-- provisioned deterministically.
--
-- Runtime contract:
--   public.journeys
--   public.memories
--   public.album_photos
--   public.memory_photos
--   storage bucket: wonderlog-photos
--
-- Security model: authenticated users can access only rows/files they own.

create table if not exists public.journeys (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_reference_id text,
  title text not null default '',
  destination text not null default '',
  country text not null default '',
  description text not null default '',
  start_date text not null,
  end_date text not null,
  accent_theme text,
  cover_photo_cloud_id uuid,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  schema_version integer not null default 1,
  unique (id, owner_id)
);

create unique index if not exists journeys_owner_local_reference_uidx
  on public.journeys(owner_id, local_reference_id)
  where local_reference_id is not null;

create index if not exists journeys_owner_updated_idx
  on public.journeys(owner_id, updated_at);

create table if not exists public.memories (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  journey_cloud_id uuid not null,
  local_reference_id text,
  title text not null default '',
  journal_text text not null default '',
  date text not null,
  location_name text,
  latitude double precision,
  longitude double precision,
  mood text,
  tags jsonb not null default '[]'::jsonb,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  schema_version integer not null default 1,
  unique (id, owner_id),
  constraint memories_tags_array_check
    check (jsonb_typeof(tags) = 'array'),
  constraint memories_journey_owner_fk
    foreign key (journey_cloud_id, owner_id)
    references public.journeys(id, owner_id)
    on delete cascade
);

create unique index if not exists memories_owner_local_reference_uidx
  on public.memories(owner_id, local_reference_id)
  where local_reference_id is not null;

create index if not exists memories_owner_journey_updated_idx
  on public.memories(owner_id, journey_cloud_id, updated_at);

create index if not exists memories_journey_owner_fk_idx
  on public.memories(journey_cloud_id, owner_id);

create table if not exists public.album_photos (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  journey_cloud_id uuid not null,
  local_reference_id text,
  remote_file_path text,
  file_name text,
  mime_type text,
  captured_at bigint,
  latitude double precision,
  longitude double precision,
  location_name text,
  display_order integer not null default 0,
  is_cover_photo boolean not null default false,
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint,
  schema_version integer not null default 1,
  unique (id, owner_id),
  constraint album_photos_journey_owner_fk
    foreign key (journey_cloud_id, owner_id)
    references public.journeys(id, owner_id)
    on delete cascade
);

create unique index if not exists album_photos_owner_local_reference_uidx
  on public.album_photos(owner_id, local_reference_id)
  where local_reference_id is not null;

create index if not exists album_photos_owner_journey_updated_idx
  on public.album_photos(owner_id, journey_cloud_id, updated_at);

create index if not exists album_photos_journey_owner_fk_idx
  on public.album_photos(journey_cloud_id, owner_id);

create table if not exists public.memory_photos (
  owner_id uuid not null references auth.users(id) on delete cascade,
  memory_cloud_id uuid not null,
  photo_cloud_id uuid not null,
  display_order integer not null default 0,
  is_hero_photo boolean not null default false,
  primary key (owner_id, memory_cloud_id, photo_cloud_id),
  constraint memory_photos_memory_owner_fk
    foreign key (memory_cloud_id, owner_id)
    references public.memories(id, owner_id)
    on delete cascade,
  constraint memory_photos_photo_owner_fk
    foreign key (photo_cloud_id, owner_id)
    references public.album_photos(id, owner_id)
    on delete cascade
);

create index if not exists memory_photos_memory_owner_fk_idx
  on public.memory_photos(memory_cloud_id, owner_id);

create index if not exists memory_photos_photo_owner_fk_idx
  on public.memory_photos(photo_cloud_id, owner_id);

alter table public.journeys enable row level security;
alter table public.memories enable row level security;
alter table public.album_photos enable row level security;
alter table public.memory_photos enable row level security;

grant select, insert, update, delete on public.journeys to authenticated;
grant select, insert, update, delete on public.memories to authenticated;
grant select, insert, update, delete on public.album_photos to authenticated;
grant select, insert, update, delete on public.memory_photos to authenticated;

drop policy if exists "wonderlog journeys select own" on public.journeys;
create policy "wonderlog journeys select own"
  on public.journeys for select
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog journeys insert own" on public.journeys;
create policy "wonderlog journeys insert own"
  on public.journeys for insert
  to authenticated
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog journeys update own" on public.journeys;
create policy "wonderlog journeys update own"
  on public.journeys for update
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog journeys delete own" on public.journeys;
create policy "wonderlog journeys delete own"
  on public.journeys for delete
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memories select own" on public.memories;
create policy "wonderlog memories select own"
  on public.memories for select
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memories insert own" on public.memories;
create policy "wonderlog memories insert own"
  on public.memories for insert
  to authenticated
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memories update own" on public.memories;
create policy "wonderlog memories update own"
  on public.memories for update
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memories delete own" on public.memories;
create policy "wonderlog memories delete own"
  on public.memories for delete
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog photos select own" on public.album_photos;
create policy "wonderlog photos select own"
  on public.album_photos for select
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog photos insert own" on public.album_photos;
create policy "wonderlog photos insert own"
  on public.album_photos for insert
  to authenticated
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog photos update own" on public.album_photos;
create policy "wonderlog photos update own"
  on public.album_photos for update
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog photos delete own" on public.album_photos;
create policy "wonderlog photos delete own"
  on public.album_photos for delete
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memory photos select own" on public.memory_photos;
create policy "wonderlog memory photos select own"
  on public.memory_photos for select
  to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memory photos insert own" on public.memory_photos;
create policy "wonderlog memory photos insert own"
  on public.memory_photos for insert
  to authenticated
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memory photos update own" on public.memory_photos;
create policy "wonderlog memory photos update own"
  on public.memory_photos for update
  to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "wonderlog memory photos delete own" on public.memory_photos;
create policy "wonderlog memory photos delete own"
  on public.memory_photos for delete
  to authenticated
  using ((select auth.uid()) = owner_id);

insert into storage.buckets (id, name, public)
values ('wonderlog-photos', 'wonderlog-photos', false)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "wonderlog photos storage select own" on storage.objects;
create policy "wonderlog photos storage select own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'wonderlog-photos'
    and owner_id = (select auth.uid()::text)
  );

drop policy if exists "wonderlog photos storage insert own" on storage.objects;
create policy "wonderlog photos storage insert own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'wonderlog-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "wonderlog photos storage update own" on storage.objects;
create policy "wonderlog photos storage update own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'wonderlog-photos'
    and owner_id = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'wonderlog-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

drop policy if exists "wonderlog photos storage delete own" on storage.objects;
create policy "wonderlog photos storage delete own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'wonderlog-photos'
    and owner_id = (select auth.uid()::text)
  );
