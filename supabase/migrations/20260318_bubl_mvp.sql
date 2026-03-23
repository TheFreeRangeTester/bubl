create extension if not exists vector;
create extension if not exists pg_cron;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  locale text,
  reputation_score int not null default 0
);

create table if not exists public.bubls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  activity_text text not null,
  feeling_text text not null,
  embedding vector(1536),
  cluster_label text,
  week_id text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  is_active boolean not null default true,
  is_flagged boolean not null default false
);

create table if not exists public.seed_clusters (
  label text primary key,
  embedding vector(1536) not null
);

create table if not exists public.reactions (
  id uuid primary key default gen_random_uuid(),
  bubl_id uuid not null references public.bubls(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  text text not null check (char_length(text) <= 120),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references public.users(id) on delete cascade,
  reported_bubl_id uuid references public.bubls(id) on delete cascade,
  reported_reaction_id uuid references public.reactions(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  check (reported_bubl_id is not null or reported_reaction_id is not null)
);

alter table public.users enable row level security;
alter table public.bubls enable row level security;
alter table public.reactions enable row level security;
alter table public.reports enable row level security;
alter table public.seed_clusters enable row level security;

drop policy if exists users_read_own on public.users;
create policy users_read_own on public.users
for select to authenticated
using (id = auth.uid());

drop policy if exists users_modify_own on public.users;
create policy users_modify_own on public.users
for all to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists bubls_read_active on public.bubls;
create policy bubls_read_active on public.bubls
for select to authenticated
using (
  is_active = true
  and is_flagged = false
  and expires_at > now()
);

drop policy if exists bubls_modify_own on public.bubls;
create policy bubls_modify_own on public.bubls
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists reactions_read_visible_parent on public.reactions;
create policy reactions_read_visible_parent on public.reactions
for select to authenticated
using (
  exists (
    select 1
    from public.bubls b
    where b.id = reactions.bubl_id
      and b.is_active = true
      and b.is_flagged = false
      and b.expires_at > now()
  )
);

drop policy if exists reactions_modify_own on public.reactions;
create policy reactions_modify_own on public.reactions
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists reports_insert_own on public.reports;
create policy reports_insert_own on public.reports
for insert to authenticated
with check (reporter_user_id = auth.uid());

drop policy if exists reports_read_own on public.reports;
create policy reports_read_own on public.reports
for select to authenticated
using (reporter_user_id = auth.uid());

drop policy if exists seed_clusters_read_all on public.seed_clusters;
create policy seed_clusters_read_all on public.seed_clusters
for select to authenticated
using (true);

create or replace function public.closest_seed_cluster(query_embedding vector(1536))
returns text
language sql
stable
as $$
  select label
  from public.seed_clusters
  order by embedding <=> query_embedding
  limit 1;
$$;

create or replace function public.flag_bubl_after_reports()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.reported_bubl_id is not null then
    update public.bubls
    set is_flagged = true
    where id = new.reported_bubl_id
      and (
        select count(*)
        from public.reports r
        where r.reported_bubl_id = new.reported_bubl_id
      ) >= 3;
  end if;

  return new;
end;
$$;

drop trigger if exists reports_flag_bubl_trigger on public.reports;
create trigger reports_flag_bubl_trigger
after insert on public.reports
for each row
execute function public.flag_bubl_after_reports();

select cron.schedule(
  'deactivate-expired-bubls',
  '0 3 * * *',
  $$
    update public.bubls
    set is_active = false
    where is_active = true
      and expires_at < now();
  $$
)
where not exists (
  select 1 from cron.job where jobname = 'deactivate-expired-bubls'
);
