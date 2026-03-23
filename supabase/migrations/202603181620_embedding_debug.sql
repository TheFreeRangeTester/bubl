alter table public.bubls
  add column if not exists embedding_cluster_label text,
  add column if not exists embedding_debug jsonb;

create or replace function public.seed_cluster_distances(
  query_embedding vector(1536),
  match_count int default 3
)
returns table(label text, distance double precision)
language sql
stable
as $$
  select sc.label,
         (sc.embedding <=> query_embedding)::double precision as distance
  from public.seed_clusters sc
  order by sc.embedding <=> query_embedding
  limit greatest(match_count, 1);
$$;
