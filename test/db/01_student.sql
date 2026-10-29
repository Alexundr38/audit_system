-- ============================================================
-- Логическая сущность «Студент»
-- Уровень 1: students (главная таблица сущности)
-- Уровень 2: student_groups (группа), gradebooks (зачётная книжка)
-- Уровень 3: gradebook_entries (записи успеваемости в зачётке)
-- ============================================================

-- Группа (уровень 2) — справочник, на который ссылается студент
CREATE TABLE IF NOT EXISTS student_groups (
    id            SERIAL PRIMARY KEY,
    code          VARCHAR(20) NOT NULL UNIQUE,   -- например 'ИВТ-21-1'
    faculty       VARCHAR(120) NOT NULL,          -- факультет
    course_year   SMALLINT NOT NULL CHECK (course_year BETWEEN 1 AND 6),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Студент (уровень 1) — главная таблица сущности
CREATE TABLE IF NOT EXISTS students (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(60) NOT NULL,
    last_name     VARCHAR(60) NOT NULL,
    middle_name   VARCHAR(60),
    birth_date    DATE,
    email         VARCHAR(120) UNIQUE,
    group_id      INTEGER REFERENCES student_groups (id) ON DELETE SET NULL, -- уровень 2
    enrolled_at   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Зачётная книжка (уровень 2) — 1:1 со студентом
CREATE TABLE IF NOT EXISTS gradebooks (
    id            SERIAL PRIMARY KEY,
    student_id    INTEGER NOT NULL UNIQUE REFERENCES students (id) ON DELETE CASCADE,
    book_number   VARCHAR(20) NOT NULL UNIQUE,    -- номер зачётки
    issued_at     DATE NOT NULL DEFAULT CURRENT_DATE,
    status        VARCHAR(20) NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'closed', 'lost'))
);

-- Записи успеваемости (уровень 3) — строки внутри зачётной книжки
CREATE TABLE IF NOT EXISTS gradebook_entries (
    id            SERIAL PRIMARY KEY,
    gradebook_id  INTEGER NOT NULL REFERENCES gradebooks (id) ON DELETE CASCADE,
    subject       VARCHAR(120) NOT NULL,
    grade         SMALLINT NOT NULL CHECK (grade BETWEEN 2 AND 5),
    semester      SMALLINT NOT NULL CHECK (semester BETWEEN 1 AND 12),
    passed_at     DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Индексы для частых выборок
CREATE INDEX IF NOT EXISTS idx_students_group_id    ON students (group_id);
CREATE INDEX IF NOT EXISTS idx_gradebook_entries_gb ON gradebook_entries (gradebook_id);