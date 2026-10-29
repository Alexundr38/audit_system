import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const { Pool } = pg;

const DATABASE_URL =
  process.env.DATABASE_URL ??
  `postgres://${process.env.POSTGRES_USER}:${process.env.POSTGRES_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.POSTGRES_DB}`;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_DIR = path.resolve(__dirname, "..", "db");

const INTERVAL_MS = Number(process.env.AGGREGATE_INTERVAL_MS ?? 60_000);

const pool = new Pool({ connectionString: DATABASE_URL });

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function ensureSchema(): Promise<void> {
  const sql = fs.readFileSync(path.join(DB_DIR, "aggregated-log.sql"), "utf8");
  await pool.query(sql);
}

async function aggregateOnce(): Promise<void> {
  const { rows } = await pool.query<{ aggregated: string; deleted: string }>(
    "SELECT * FROM aggregate_audit_log()",
  );
  const { aggregated, deleted } = rows[0];
  if (Number(aggregated) > 0 || Number(deleted) > 0) {
    console.log(`[${new Date().toISOString()}] aggregated=${aggregated} deleted=${deleted}`);
  }
}

async function main(): Promise<void> {
  console.log(`Агрегатор запущен, интервал ${INTERVAL_MS} мс.`);
  while (true) {
    const started = Date.now();
    try {
      await ensureSchema();
      await aggregateOnce();
    } catch (err) {
      console.error(`[${new Date().toISOString()}] Ошибка агрегации:`, err);
    }
    const elapsed = Date.now() - started;
    await sleep(Math.max(0, INTERVAL_MS - elapsed));
  }
}

for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, async () => {
    console.log(`Получен ${sig}, останавливаюсь.`);
    await pool.end();
    process.exit(0);
  });
}

main().catch(async (err) => {
  console.error("Fatal:", err);
  await pool.end();
  process.exit(1);
});