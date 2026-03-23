import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing required environment variables");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const seedLabels = [
  "music",
  "fitness",
  "work",
  "relationships",
  "creativity",
  "learning",
  "travel",
  "food",
  "health",
  "gaming"
];

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const { bubl_id, activity_text } = await req.json();
    if (!bubl_id || !activity_text) {
      return json({ error: "bubl_id and activity_text are required" }, 400);
    }

    await ensureSeedEmbeddings();

    const embedding = await embeddingFor(activity_text);
    const embeddingVector = vectorLiteral(embedding);

    const { data: clusterData, error: clusterError } = await supabase.rpc(
      "closest_seed_cluster",
      { query_embedding: embeddingVector }
    );

    if (clusterError) {
      return json({ error: clusterError.message }, 500);
    }

    const clusterLabel = typeof clusterData === "string" ? clusterData : null;
    const { data: distancesData, error: distancesError } = await supabase.rpc(
      "seed_cluster_distances",
      { query_embedding: embeddingVector, match_count: 3 }
    );

    if (distancesError) {
      return json({ error: distancesError.message }, 500);
    }

    const topMatches = Array.isArray(distancesData)
      ? distancesData.map((row: { label: string; distance: number }) => ({
          label: row.label,
          distance: Number(row.distance)
        }))
      : [];
    const { data: currentBubl, error: currentBublError } = await supabase
      .from("bubls")
      .select("cluster_label")
      .eq("id", bubl_id)
      .single();

    if (currentBublError) {
      return json({ error: currentBublError.message }, 500);
    }

    const finalClusterLabel = currentBubl?.cluster_label ?? clusterLabel;

    const { error: updateError } = await supabase
      .from("bubls")
      .update({
        embedding: embeddingVector,
        cluster_label: finalClusterLabel,
        embedding_cluster_label: clusterLabel,
        embedding_debug: { top_matches: topMatches }
      })
      .eq("id", bubl_id);

    if (updateError) {
      return json({ error: updateError.message }, 500);
    }

    return json({
      ok: true,
      cluster_label: finalClusterLabel,
      embedding_cluster_label: clusterLabel,
      top_matches: topMatches
    });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});

async function ensureSeedEmbeddings() {
  const { data, error } = await supabase
    .from("seed_clusters")
    .select("label", { count: "exact" });

  if (error) {
    throw error;
  }

  const existing = new Set((data ?? []).map((row) => row.label));
  const missing = seedLabels.filter((label) => !existing.has(label));

  if (missing.length === 0) {
    return;
  }

  const vectors = await embeddingsFor(missing);
  const rows = missing.map((label, index) => ({
    label,
    embedding: vectorLiteral(vectors[index])
  }));

  const { error: upsertError } = await supabase
    .from("seed_clusters")
    .upsert(rows, { onConflict: "label" });

  if (upsertError) {
    throw upsertError;
  }
}

async function embeddingFor(text: string): Promise<number[]> {
  const [vector] = await embeddingsFor([text]);
  return vector;
}

async function embeddingsFor(input: string[]): Promise<number[][]> {
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${OPENAI_API_KEY}`
    },
    body: JSON.stringify({
      model: "text-embedding-3-small",
      input
    })
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI embedding request failed: ${response.status} ${body}`);
  }

  const payload = await response.json();
  return payload.data.map((item: { embedding: number[] }) => item.embedding);
}

function vectorLiteral(values: number[]): string {
  return `[${values.join(",")}]`;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}
