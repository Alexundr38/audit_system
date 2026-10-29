-- ============================================================
-- Агрегированная таблица аудита.
-- Одна строка = одна операция (один operation_id из audit_log).
-- Заполняется функцией aggregate_audit_log(), которую вызывает
-- воркер src/aggregate-audit.ts по расписанию.
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_log_aggregated (
    id              BIGSERIAL PRIMARY KEY,
    operation_id    BIGINT NOT NULL UNIQUE,  -- откуда пришла операция
    transaction_id  BIGINT,                  -- ID транзакции БД
    occurred_at     TIMESTAMPTZ NOT NULL,    -- когда произошло изменение
    changes         JSONB NOT NULL,          -- см. формат ниже
    aggregated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Индексы под частые запросы
CREATE INDEX IF NOT EXISTS idx_audit_log_aggregated_tx
    ON audit_log_aggregated (transaction_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_aggregated_table_time
    ON audit_log_aggregated ((changes->>'table_name'), occurred_at);

CREATE INDEX IF NOT EXISTS idx_audit_log_aggregated_changes_gin
    ON audit_log_aggregated USING GIN (changes);

-- ============================================================
-- Агрегация: сворачивает audit_log по operation_id и удаляет
-- обработанные строки. Один вызов = одна транзакция.
-- Возвращает (aggregated, deleted) для логов.
-- ============================================================
CREATE OR REPLACE FUNCTION aggregate_audit_log()
RETURNS TABLE(aggregated BIGINT, deleted BIGINT) AS $$
DECLARE
    v_aggregated BIGINT;
    v_deleted    BIGINT;
BEGIN
    WITH grouped AS (
        SELECT
            operation_id,
            max(transaction_id) AS transaction_id,
            max(row_id)         AS row_id,
            max(table_name)     AS table_name,
            max(operation)      AS operation,
            min(occurred_at)    AS occurred_at,
            jsonb_object_agg(
                column_name,
                jsonb_build_object('old', old_value, 'new', new_value)
            ) AS fields
        FROM audit_log
        GROUP BY operation_id
    ),
    inserted AS (
        INSERT INTO audit_log_aggregated
            (operation_id, transaction_id, occurred_at, changes)
        SELECT
            operation_id,
            transaction_id,
            occurred_at,
            jsonb_build_object(
                'table_name', table_name,
                'row_id',     row_id,
                'operation',  operation,
                'fields',     fields
            )
        FROM grouped
        ON CONFLICT (operation_id) DO NOTHING
        RETURNING operation_id
    ),
    deleted AS (
        DELETE FROM audit_log
        WHERE operation_id IN (SELECT operation_id FROM inserted)
        RETURNING id
    )
    SELECT
        (SELECT count(*) FROM inserted),
        (SELECT count(*) FROM deleted)
    INTO v_aggregated, v_deleted;

    RETURN QUERY SELECT v_aggregated, v_deleted;
END;
$$ LANGUAGE plpgsql;