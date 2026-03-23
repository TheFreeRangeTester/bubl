alter table public.bubls
  add column if not exists subcategory_id text,
  add column if not exists topic_id text,
  add column if not exists language_code text;

update public.bubls
set subcategory_id = cluster_label
where subcategory_id is null
  and cluster_label is not null;

update public.bubls
set topic_id = topic
where topic_id is null
  and topic is not null;

update public.bubls b
set language_code = coalesce(u.locale, 'en')
from public.users u
where b.user_id = u.id
  and b.language_code is null;

update public.bubls
set language_code = 'en'
where language_code is null;

create index if not exists idx_bubls_week_subcategory_active
  on public.bubls (week_id, subcategory_id, is_active, is_flagged);

create index if not exists idx_bubls_topic_id
  on public.bubls (topic_id);

comment on column public.bubls.subcategory_id is 'Canonical subcategory identifier, independent of localized UI labels.';
comment on column public.bubls.topic_id is 'Canonical inferred topic identifier used for fine-grained matching.';
comment on column public.bubls.language_code is 'ISO language code for the bubl text, used for multilingual inference and analysis.';
