-- ============================================================
-- Логическая сущность «Приёмная кампания»
-- Уровень 1: applicants (главная таблица сущности)
-- Уровень 2: majors (направление), applications (заявления)
-- Уровень 3: application_documents (документы по заявлению)
-- ============================================================

-- Направление подготовки (уровень 2) — справочник
CREATE TABLE IF NOT EXISTS majors (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,        -- например '09.03.04'
    title       VARCHAR(150) NOT NULL,
    budget_places SMALLINT NOT NULL DEFAULT 0 CHECK (budget_places >= 0)
);

-- Абитуриент (уровень 1) — главная таблица сущности
CREATE TABLE IF NOT EXISTS applicants (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(60) NOT NULL,
    last_name     VARCHAR(60) NOT NULL,
    middle_name   VARCHAR(60),
    birth_date    DATE,
    email         VARCHAR(120) UNIQUE,
    phone         VARCHAR(20),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Заявление абитуриента (уровень 2) — ссылается на уровень 1 и справочник
CREATE TABLE IF NOT EXISTS applications (
    id            SERIAL PRIMARY KEY,
    applicant_id  INTEGER NOT NULL REFERENCES applicants (id) ON DELETE CASCADE,
    major_id      INTEGER NOT NULL REFERENCES majors (id) ON DELETE RESTRICT,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'rejected', 'withdrawn')),
    submitted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (applicant_id, major_id)
);

-- Документы по заявлению (уровень 3) — вложения к конкретному заявлению
CREATE TABLE IF NOT EXISTS application_documents (
    id             SERIAL PRIMARY KEY,
    application_id INTEGER NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
    doc_type       VARCHAR(40) NOT NULL,            -- например 'аттестат', 'паспорт'
    file_name      VARCHAR(200),
    uploaded_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Индексы для частых выборок
CREATE INDEX IF NOT EXISTS idx_applications_applicant ON applications (applicant_id);
CREATE INDEX IF NOT EXISTS idx_applications_major      ON applications (major_id);
CREATE INDEX IF NOT EXISTS idx_application_documents_a ON application_documents (application_id);