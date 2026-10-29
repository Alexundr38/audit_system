import "dotenv/config";
import pg from "pg";

const { Pool } = pg;

const DATABASE_URL =
  process.env.DATABASE_URL ??
  `postgres://${process.env.POSTGRES_USER}:${process.env.POSTGRES_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.POSTGRES_DB}`;

const pool = new Pool({ connectionString: DATABASE_URL });

async function main(): Promise<void> {
  const client = await pool.connect();
  try {
    console.log("Подключение к PostgreSQL установлено.");

    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        text TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    await client.query("INSERT INTO messages (text) VALUES ($1)", [
      "Привет из TypeScript!",
    ]);

    const { rows } = await client.query("SELECT * FROM messages ORDER BY id DESC LIMIT 5");
    console.log("Последние записи:", rows);

    await pool.end();
    console.log("Готово. Приложение завершило работу.");
  } finally {
    client.release();
  }
}

main().catch(async (err) => {
  console.error("Ошибка:", err);
  await pool.end();
  process.exit(1);
});