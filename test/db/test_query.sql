
insert into student_groups (code, faculty, course_year)
values ('3364', 'fcti', 4);

insert into students (first_name, last_name, middle_name, birth_date, email, group_id)
values ('aaa', 'bbssb', 'ccddsdc', '2006-10-16', 'addda@aaa.aaa', 1);

insert into students (first_name, last_name, middle_name, birth_date, email, group_id)
values ('a2aa', 'bbb', 'ccc', '2006-10-16', 'ada@aaa.aaa', 1);

update students
set first_name = 'dkjdsjds'
where first_name = 'aaa';

delete from students where first_name = 'a2aa';

UPDATE students
SET first_name = 'Иван', email = 'ivan@example.com'
WHERE id = 1;


SELECT id, operation_id, changes
FROM audit_log_aggregated
ORDER BY id DESC
LIMIT 3;