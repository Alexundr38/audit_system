-- ============================================================
-- Общая таблица аудита изменений.
-- Сами триггерные функции генерируются скриптом setup-audit.ts
-- под каждую таблицу из audit-config.json (с учётом правил полей),
-- поэтому здесь лежит только общая инфраструктура: последовательность
-- для группировки операций и сама таблица audit_log.
-- Скрипт идемпотентный: можно запускать повторно.
-- ============================================================

-- Последовательность для группировки операций: все поля одной
-- строки-изменения получают один operation_id.
CREATE SEQUENCE IF NOT EXISTS audit_log_operation_id_seq;

CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL PRIMARY KEY,           -- id записи аудита
    operation_id    BIGINT NOT NULL,                 -- id операции (общий для всех полей одного изменения)
    transaction_id  BIGINT,                          -- ID транзакции БД (pg_current_xact_id)
    row_id          TEXT,                            -- значение первичного ключа изменённой строки
    table_name      TEXT NOT NULL,
    operation       TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    column_name     TEXT NOT NULL,
    old_value       TEXT,
    new_value       TEXT
);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_time       ON audit_log (table_name, occurred_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation_id     ON audit_log (operation_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_transaction_id   ON audit_log (transaction_id);