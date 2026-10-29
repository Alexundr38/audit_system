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

// Только безопасные идентификаторы (исключает SQL-инъекции через конфиг)
const IDENTIFIER_RE = /^[a-z_][a-z0-9_]*$/;

interface TableRule {
  table: string;
  fields?: string[];
  exclude?: string[];
}

function assertIdentifier(name: string, label: string): void {
  if (!IDENTIFIER_RE.test(name)) {
    throw new Error(`Некорректный ${label} «${name}»`);
  }
}

function arrayLiteral(fields: string[] | undefined): string {
  if (!fields || fields.length === 0) return "NULL";
  return `ARRAY[${fields.map((f) => `'${f}'`).join(", ")}]`;
}

/**
 * Правила выбора полей для таблицы:
 * - fields задан  -> пишем только перечисленные поля;
 * - exclude задан -> пишем все поля, кроме перечисленных;
 * - ни то, ни другое -> пишем все поля.
 */
function buildTriggerFunction(rule: TableRule): string {
  const { table, fields, exclude } = rule;
  assertIdentifier(table, "идентификатор таблицы");
  (fields ?? []).forEach((f) => assertIdentifier(f, "имя поля"));
  (exclude ?? []).forEach((f) => assertIdentifier(f, "имя поля"));

  const includeArr = arrayLiteral(fields);
  const excludeArr = arrayLiteral(exclude);

  return `
CREATE OR REPLACE FUNCTION audit_trigger_${table}()
RETURNS TRIGGER AS $fn$
DECLARE
    op_id          BIGINT;
    row_id         TEXT;
    new_data       JSONB;
    old_data       JSONB;
    j              RECORD;
    filter_include TEXT[] := ${includeArr};
    filter_exclude TEXT[] := ${excludeArr};
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN new_data := to_jsonb(NEW); END IF;
    IF TG_OP IN ('UPDATE', 'DELETE') THEN old_data := to_jsonb(OLD); END IF;

    op_id := nextval('audit_log_operation_id_seq');

    -- Значение первичного ключа (колонка 'id'), если она есть
    IF new_data ? 'id' THEN
        row_id := new_data ->> 'id';
    ELSIF old_data ? 'id' THEN
        row_id := old_data ->> 'id';
    END IF;

    -- На INSERT все колонки попадут с new_val, на DELETE — с old_val,
    -- на UPDATE — только те, где old_val IS DISTINCT FROM new_val.
    FOR j IN
        SELECT COALESCE(n.k, o.k) AS col_name,
               o.v AS old_val,
               n.v AS new_val
        FROM jsonb_each_text(COALESCE(new_data, '{}'::jsonb)) AS n(k, v)
        FULL JOIN jsonb_each_text(COALESCE(old_data, '{}'::jsonb)) AS o(k, v) USING (k)
        WHERE n.v IS DISTINCT FROM o.v
    LOOP
        IF filter_include IS NOT NULL AND NOT (j.col_name = ANY(filter_include)) THEN
            CONTINUE;
        END IF;
        IF filter_exclude IS NOT NULL AND (j.col_name = ANY(filter_exclude)) THEN
            CONTINUE;
        END IF;

        INSERT INTO audit_log (operation_id, transaction_id, row_id, table_name, operation, occurred_at, column_name, old_value, new_value)
        VALUES (op_id, pg_current_xact_id()::text::bigint, row_id, TG_TABLE_NAME, TG_OP, now(), j.col_name, j.old_val, j.new_val);
    END LOOP;

    RETURN COALESCE(NEW, OLD);
END;
$fn$ LANGUAGE plpgsql;
`;
}

function buildTrigger(rule: TableRule): string {
  return `DROP TRIGGER IF EXISTS trg_audit_${rule.table} ON ${rule.table};
CREATE TRIGGER trg_audit_${rule.table}
AFTER INSERT OR UPDATE OR DELETE ON ${rule.table}
FOR EACH ROW EXECUTE FUNCTION audit_trigger_${rule.table}();`;
}

function describeMode(rule: TableRule): string {
  if (rule.fields?.length) return `только поля: ${rule.fields.join(", ")}`;
  if (rule.exclude?.length) return `все, кроме: ${rule.exclude.join(", ")}`;
  return "все поля";
}

async function main(): Promise<void> {
  const configPath = path.join(DB_DIR, "audit-config.json");
  const config: { tables: TableRule[] } = JSON.parse(
    fs.readFileSync(configPath, "utf8"),
  );

  const pool = new Pool({ connectionString: DATABASE_URL });
  try {
    console.log("Подключение к PostgreSQL установлено.");

    const auditSql = fs.readFileSync(
      path.join(DB_DIR, "audit-log.sql"),
      "utf8",
    );
    await pool.query(auditSql);
    console.log("Общая таблица audit_log готова.");

    for (const rule of config.tables) {
      await pool.query(buildTriggerFunction(rule));
      await pool.query(buildTrigger(rule));
      console.log(
        `Триггер навешан на ${rule.table} (${describeMode(rule)})`,
      );
    }

    console.log("Готово. Аудит включён.");
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error("Ошибка:", err);
  process.exit(1);
});