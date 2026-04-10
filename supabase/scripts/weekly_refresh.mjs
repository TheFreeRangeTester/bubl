#!/usr/bin/env node

/**
 * Weekly refresh helper for demo/staging environments.
 *
 * Runs the two terminal steps we currently do manually when a new ISO week starts:
 * 1. Seed current-week bubls
 * 2. Backfill missing embeddings for that same week
 *
 * Required env vars:
 * - SUPABASE_URL
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional:
 * - RESET_SEED=1 (default true for this wrapper)
 * - BUBL_SEED_COUNT
 * - BUBL_EMBED_LIMIT
 * - BUBL_EMBED_CONCURRENCY
 * - ONLY_NULL=1 (default true)
 */

import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const weekId = process.env.BUBL_WEEK_ID ?? isoWeekId(new Date());
const resetSeed = normalizeBoolean(process.env.RESET_SEED, true);
const onlyNull = normalizeBoolean(process.env.ONLY_NULL, true);

async function main() {
  console.log(`Starting weekly refresh for week ${weekId}...`);
  console.log("");

  await runNodeScript("seed_bubls.mjs", {
    ...process.env,
    RESET_SEED: resetSeed ? "1" : "0"
  });

  console.log("");

  await runNodeScript("backfill_bubl_embeddings.mjs", {
    ...process.env,
    BUBL_WEEK_ID: weekId,
    ONLY_NULL: onlyNull ? "1" : "0"
  });

  console.log("");
  console.log(`Weekly refresh completed for ${weekId}.`);
}

function runNodeScript(scriptName, env) {
  const scriptPath = path.join(__dirname, scriptName);
  console.log(`> node ${path.relative(process.cwd(), scriptPath)}`);

  return new Promise((resolve, reject) => {
    const child = spawn("node", [scriptPath], {
      cwd: process.cwd(),
      env,
      stdio: "inherit"
    });

    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${scriptName} failed with exit code ${code ?? "unknown"}`));
      }
    });

    child.on("error", reject);
  });
}

function normalizeBoolean(value, fallback) {
  if (value == null || value === "") return fallback;
  return ["1", "true", "yes"].includes(String(value).toLowerCase());
}

function isoWeekId(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-${String(weekNo).padStart(2, "0")}`;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
