# audit_system


# Audit System

## Первый запуск

```bash
# переименовать .env.example в .env

# Поднять контейнеры (db + app + aggregator)
docker compose up -d --build

# Дождаться healthy у db
docker compose ps

# Навесить триггеры аудита (обязательно, один раз)
docker compose exec app node dist/setup-audit.js
```


## Файлы

| Файл | Назначение |
|---|---|
| `docker-compose.yml` | сервисы `db`, `app`, `aggregator` |
| `.env` | переменные окружения |
| `db/01_student.sql` | таблицы сущности «Студент» |
| `db/02_teacher.sql` | таблицы сущности «Преподаватель» |
| `db/03_enrollment.sql` | таблицы сущности «Приёмная кампания» |
| `db/audit-log.sql` | таблица `audit_log` (сырые записи) |
| `db/aggregated-log.sql` | таблица `audit_log_aggregated` + функция `aggregate_audit_log()` |
| `db/audit-config.json` | какие таблицы и поля аудитить |
| `src/index.ts` | демо-скрипт приложения |
| `src/setup-audit.ts` | генерация триггеров аудита |
| `src/aggregate-audit.ts` | воркер агрегации `audit_log` → `audit_log_aggregated` |


## Troubleshooting

| Проблема | Решение |
|---|---|
| Таблицы не создались | init-скрипты идут только на пустом volume → `docker compose down -v && docker compose up -d --build` |
| Нет записей в `audit_log` | не выполнен шаг 4 (`setup-audit.js`) |
| `cannot cast type xid8 to bigint` | в `setup-audit.ts` должно быть `pg_current_xact_id()::text::bigint` → `docker compose build app` + шаг 4 |
| Порт занят | поменять `DB_PORT` в `.env` |