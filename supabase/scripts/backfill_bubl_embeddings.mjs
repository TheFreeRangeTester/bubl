#!/usr/bin/env node

/**
 * Backfill embeddings for existing bubls by invoking the deployed Supabase Edge Function.
 *
 * Required env vars:
 * - SUPABASE_URL
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional:
 * - BUBL_WEEK_ID=YYYY-WW (defaults to current ISO week)
 * - ONLY_NULL=1 (default true; only process rows with embedding IS NULL)
 * - BUBL_EMBED_LIMIT=200 (default 200)
 * - BUBL_EMBED_CONCURRENCY=1 (default 1)
 */

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const weekId = process.env.BUBL_WEEK_ID ?? isoWeekId(new Date());
const onlyNull = !["0", "false", "no"].includes((process.env.ONLY_NULL ?? "1").toLowerCase());
const limit = Number(process.env.BUBL_EMBED_LIMIT ?? 200);
const concurrency = Math.max(1, Number(process.env.BUBL_EMBED_CONCURRENCY ?? 1));

async function main() {
  console.log(`Loading bubls for week ${weekId}...`);
  const bubls = await listBublsForWeek(weekId, { onlyNull, limit });
  console.log(`Found ${bubls.length} bubls to process${onlyNull ? " (embedding is null)" : ""}.`);

  if (bubls.length === 0) {
    console.log("Nothing to backfill.");
    return;
  }

  let processed = 0;
  let succeeded = 0;
  let failed = 0;

  for (let index = 0; index < bubls.length; index += concurrency) {
    const batch = bubls.slice(index, index + concurrency);
    const results = await Promise.allSettled(batch.map(generateEmbeddingForBubl));

    for (const result of results) {
      processed += 1;
      if (result.status === "fulfilled") {
        succeeded += 1;
      } else {
        failed += 1;
        console.error(result.reason.message);
      }
    }

    console.log(`  -> ${processed}/${bubls.length} (ok=${succeeded}, failed=${failed})`);
  }

  console.log("Backfill completed.");
  console.log(`Succeeded: ${succeeded}`);
  console.log(`Failed: ${failed}`);
}

async function listBublsForWeek(week_id, { onlyNull, limit }) {
  const url = new URL(`${supabaseUrl}/rest/v1/bubls`);
  url.searchParams.set("select", "id,activity_text,feeling_text,embedding");
  url.searchParams.set("week_id", `eq.${week_id}`);
  url.searchParams.set("is_active", "eq.true");
  url.searchParams.set("is_flagged", "eq.false");
  url.searchParams.set("order", "created_at.desc");
  url.searchParams.set("limit", String(limit));

  if (onlyNull) {
    url.searchParams.set("embedding", "is.null");
  }

  const resp = await fetch(url.toString(), {
    method: "GET",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json"
    }
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`listBublsForWeek failed: ${resp.status} ${JSON.stringify(payload)}`);
  }

  return Array.isArray(payload) ? payload : [];
}

async function generateEmbeddingForBubl(bubl) {
  const combinedText = `${bubl.activity_text}\n${bubl.feeling_text}`;
  const resp = await fetch(`${supabaseUrl}/functions/v1/generate-embedding`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      bubl_id: bubl.id,
      activity_text: combinedText
    })
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`generateEmbeddingForBubl failed for ${bubl.id}: ${resp.status} ${JSON.stringify(payload)}`);
  }

  return payload;
}

async function parseJson(resp) {
  const text = await resp.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function isoWeekId(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-${String(weekNo).padStart(2, "0")}`;
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
