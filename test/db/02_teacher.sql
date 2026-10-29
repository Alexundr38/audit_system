-- ============================================================
-- Логическая сущность «Преподаватель»
-- Уровень 1: teachers (главная таблица сущности)
-- Уровень 2: departments (кафедра), courses (дисциплина)
-- Уровень 3: course_assignments (распределение дисциплин за преподавателями)
-- ============================================================

-- Кафедра (уровень 2) — справочник
CREATE TABLE IF NOT EXISTS departments (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    head_name   VARCHAR(120),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Дисциплина (уровень 2) — справочник учебных курсов
CREATE TABLE IF NOT EXISTS courses (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(150) NOT NULL,
    code        VARCHAR(20) UNIQUE,
    credits     SMALLINT NOT NULL DEFAULT 3 CHECK (credits > 0),
    department_id INTEGER REFERENCES departments (id) ON DELETE SET NULL
);

-- Преподаватель (уровень 1) — главная таблица сущности
CREATE TABLE IF NOT EXISTS teachers (
    id            SERIAL PRIMARY KEY,
    first_name    VARCHAR(60) NOT NULL,
    last_name     VARCHAR(60) NOT NULL,
    middle_name   VARCHAR(60),
    email         VARCHAR(120) UNIQUE,
    degree        VARCHAR(40),                       -- учёная степень
    department_id INTEGER REFERENCES departments (id) ON DELETE SET NULL, -- уровень 2
    hired_at      DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Распределение дисциплин (уровень 3) — связь преподаватель <-> дисциплина
CREATE TABLE IF NOT EXISTS course_assignments (
    id            SERIAL PRIMARY KEY,
    teacher_id    INTEGER NOT NULL REFERENCES teachers (id) ON DELETE CASCADE,
    course_id     INTEGER NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
    semester      SMALLINT NOT NULL CHECK (semester BETWEEN 1 AND 12),
    year          SMALLINT NOT NULL DEFAULT EXTRACT(YEAR FROM now()),
    UNIQUE (teacher_id, course_id, semester, year)
);

-- Индексы для частых выборок
CREATE INDEX IF NOT EXISTS idx_teachers_department_id ON teachers (department_id);
CREATE INDEX IF NOT EXISTS idx_course_assignments_teacher ON course_assignments (teacher_id);
CREATE INDEX IF NOT EXISTS idx_course_assignments_course   ON course_assignments (course_id);