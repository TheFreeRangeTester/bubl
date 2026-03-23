create table if not exists public.categories (
  id text primary key,
  name text not null,
  sort_order int not null,
  is_active boolean not null default true
);

insert into public.categories (id, name, sort_order)
values
  ('work', 'Trabajo', 1),
  ('study', 'Estudio', 2),
  ('health', 'Salud', 3),
  ('relationships', 'Relaciones', 4),
  ('creativity', 'Creatividad', 5),
  ('hobbies', 'Hobbies', 6),
  ('life', 'Vida personal', 7)
on conflict (id) do update
set
  name = excluded.name,
  sort_order = excluded.sort_order,
  is_active = true;

alter table public.users
  add column if not exists alias text;

update public.users
set alias = 'Bubl ' || substr(replace(id::text, '-', ''), 1, 6)
where alias is null or btrim(alias) = '';

alter table public.users
  alter column alias set default 'Bubl user';

alter table public.bubls
  add column if not exists category_id text references public.categories(id);

update public.bubls
set category_id = case cluster_label
  when 'work' then 'work'
  when 'learning' then 'study'
  when 'health' then 'health'
  when 'relationships' then 'relationships'
  when 'creativity' then 'creativity'
  when 'gaming' then 'hobbies'
  when 'music' then 'hobbies'
  when 'food' then 'hobbies'
  when 'travel' then 'life'
  when 'fitness' then 'health'
  else 'life'
end
where category_id is null;

alter table public.bubls
  alter column category_id set default 'life';

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'bubls'
      and column_name = 'category_id'
  ) then
    update public.bubls
    set category_id = 'life'
    where category_id is null;
  end if;
end $$;

alter table public.reactions
  add column if not exists type text;

update public.reactions
set type = case
  when lower(coalesce(text, '')) like '%entiendo%' then 'i_get_it'
  when lower(coalesce(text, '')) like '%tambien%' then 'same_here'
  when lower(coalesce(text, '')) like '%paso%' then 'been_there'
  else 'rooting_for_you'
end
where type is null;

alter table public.reactions
  alter column type set default 'i_get_it';

create unique index if not exists bubls_one_active_per_week
  on public.bubls (user_id, week_id)
  where is_active = true;

create unique index if not exists reactions_one_per_user_per_bubl
  on public.reactions (bubl_id, user_id);

create or replace function public.bubl_contains_blocked_pattern(input text)
returns boolean
language sql
immutable
as $$
  select
    input ~* '(https?:\/\/|www\.)'
    or input ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
    or input ~* '(^|[^0-9])\+?[0-9][0-9\-\(\) ]{7,}[0-9]'
    or input ~* '(^|\s)@[A-Za-z0-9_\.]+';
$$;

create or replace function public.validate_bubl_content()
returns trigger
language plpgsql
as $$
begin
  if public.bubl_contains_blocked_pattern(coalesce(new.activity_text, ''))
     or public.bubl_contains_blocked_pattern(coalesce(new.feeling_text, '')) then
    raise exception 'posts cannot contain contact details or external links';
  end if;

  if char_length(coalesce(new.activity_text, '')) > 140 then
    raise exception 'activity_text too long';
  end if;

  if char_length(coalesce(new.feeling_text, '')) > 220 then
    raise exception 'feeling_text too long';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_bubl_content_trigger on public.bubls;
create trigger validate_bubl_content_trigger
before insert or update on public.bubls
for each row
execute function public.validate_bubl_content();

alter table public.categories enable row level security;

drop policy if exists categories_read_all on public.categories;
create policy categories_read_all on public.categories
for select to authenticated
using (is_active = true);
