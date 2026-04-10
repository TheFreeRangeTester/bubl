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

update public.reactions
set text = case type
  when 'same_here' then 'Yo tambien'
  when 'i_get_it' then 'Te entiendo'
  when 'been_there' then 'Me paso'
  when 'rooting_for_you' then 'Estoy con vos'
  else coalesce(text, 'Te entiendo')
end
where text is null or btrim(text) = '';

alter table public.reactions
  alter column type set default 'i_get_it';

alter table public.reactions
  alter column text set default 'Te entiendo';

with ranked_reactions as (
  select
    id,
    row_number() over (
      partition by bubl_id, user_id
      order by created_at desc, id desc
    ) as rn
  from public.reactions
)
delete from public.reactions r
using ranked_reactions rr
where r.id = rr.id
  and rr.rn > 1;

create unique index if not exists reactions_one_per_user_per_bubl
  on public.reactions (bubl_id, user_id);
