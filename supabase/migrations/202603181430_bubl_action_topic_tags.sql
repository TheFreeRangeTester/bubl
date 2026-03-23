alter table public.bubls
  add column if not exists action text,
  add column if not exists topic text,
  add column if not exists tags text[] not null default '{}';

create index if not exists idx_bubls_week_action_active
  on public.bubls (week_id, action, is_active, is_flagged);

create index if not exists idx_bubls_topic
  on public.bubls (topic);

create index if not exists idx_bubls_tags_gin
  on public.bubls using gin (tags);

update public.bubls
set action = coalesce(action,
  case cluster_label
    when 'gaming' then 'playing'
    when 'music' then 'listening'
    when 'fitness' then 'training'
    when 'work' then 'working_on'
    when 'relationships' then 'caring'
    when 'creativity' then 'creating'
    when 'learning' then 'learning'
    when 'travel' then 'traveling'
    when 'food' then 'cooking'
    when 'health' then 'caring'
    else 'other'
  end
)
where action is null;
