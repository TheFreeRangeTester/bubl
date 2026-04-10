create index if not exists idx_bubls_embedding_ivfflat
  on public.bubls using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

create or replace function public.match_bubls_by_embedding(
  query_bubl_id uuid,
  match_count int default 12
)
returns table(id uuid, distance double precision)
language sql
stable
as $$
  select candidate.id,
         (candidate.embedding <=> base.embedding)::double precision as distance
  from public.bubls base
  join public.bubls candidate
    on candidate.id <> base.id
   and candidate.user_id <> base.user_id
   and candidate.week_id = base.week_id
   and candidate.is_active = true
   and candidate.is_flagged = false
   and candidate.expires_at > now()
   and candidate.embedding is not null
   and coalesce(candidate.subcategory_id, candidate.cluster_label) = coalesce(base.subcategory_id, base.cluster_label)
  where base.id = query_bubl_id
    and base.embedding is not null
  order by candidate.embedding <=> base.embedding
  limit greatest(match_count, 1);
$$;
