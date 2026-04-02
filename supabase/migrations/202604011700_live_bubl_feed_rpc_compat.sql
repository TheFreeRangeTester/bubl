create or replace function public.get_my_live_bubl_feed(
  current_user_id uuid,
  current_week_id text,
  match_count int default 12
)
returns jsonb
language plpgsql
stable
as $$
declare
  anchor_bubl public.bubls%rowtype;
  best_distance double precision;
begin
  select b.*
    into anchor_bubl
  from public.bubls b
  where b.user_id = current_user_id
    and b.week_id = current_week_id
    and b.is_active = true
    and b.is_flagged = false
    and b.expires_at > now()
  order by b.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'my_bubl', null,
      'related_bubls', '[]'::jsonb
    );
  end if;

  select min(match.distance)
    into best_distance
  from public.match_bubls_by_embedding(anchor_bubl.id, greatest(match_count * 2, 24)) match;

  return jsonb_build_object(
    'my_bubl', to_jsonb(anchor_bubl),
    'related_bubls',
      coalesce(
        (
          with embedding_matches as (
            select
              match.id,
              match.distance,
              row_number() over (order by match.distance asc) as embedding_rank
            from public.match_bubls_by_embedding(anchor_bubl.id, greatest(match_count * 2, 24)) match
          ),
          ranked_candidates as (
            select
              candidate.*,
              embedding_matches.distance,
              embedding_matches.embedding_rank
            from public.bubls candidate
            left join embedding_matches
              on embedding_matches.id = candidate.id
            where candidate.week_id = anchor_bubl.week_id
              and candidate.user_id <> current_user_id
              and candidate.is_active = true
              and candidate.is_flagged = false
              and candidate.expires_at > now()
              and coalesce(candidate.subcategory_id, candidate.cluster_label) =
                  coalesce(anchor_bubl.subcategory_id, anchor_bubl.cluster_label)
              and (
                embedding_matches.distance is null
                or best_distance is null
                or embedding_matches.distance <= least(0.38, best_distance + 0.08)
              )
          ),
          selected_candidates as (
            select
              row_number() over (
                order by
                  case when ranked_candidates.embedding_rank is null then 1 else 0 end,
                  ranked_candidates.embedding_rank asc nulls last,
                  ranked_candidates.created_at desc
              ) as sort_position,
              to_jsonb(ranked_candidates)
                - 'distance'
                - 'embedding_rank' as bubl_json
            from ranked_candidates
            order by
              case when ranked_candidates.embedding_rank is null then 1 else 0 end,
              ranked_candidates.embedding_rank asc nulls last,
              ranked_candidates.created_at desc
            limit greatest(match_count, 1)
          )
          select jsonb_agg(selected_candidates.bubl_json order by selected_candidates.sort_position)
          from selected_candidates
        ),
        '[]'::jsonb
      )
  );
end;
$$;
