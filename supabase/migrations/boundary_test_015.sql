BEGIN;

-- ==============================================================================
-- 0. PRIVILEGED SETUP (postgres role)
-- ==============================================================================
DO $$
BEGIN
    PERFORM set_config('test.student1', gen_random_uuid()::text, true);
    PERFORM set_config('test.student2', gen_random_uuid()::text, true);
    PERFORM set_config('test.student3_inactive', gen_random_uuid()::text, true);
    PERFORM set_config('test.teacherA', gen_random_uuid()::text, true);
    PERFORM set_config('test.teacherB', gen_random_uuid()::text, true);
    PERFORM set_config('test.admin', gen_random_uuid()::text, true);
    PERFORM set_config('test.batchA', gen_random_uuid()::text, true);
    PERFORM set_config('test.batchB', gen_random_uuid()::text, true);
    PERFORM set_config('test.course_id', gen_random_uuid()::text, true);
    PERFORM set_config('test.doubtA', gen_random_uuid()::text, true);
    PERFORM set_config('test.doubtB', gen_random_uuid()::text, true);

    INSERT INTO auth.users (id) VALUES 
        (current_setting('test.student1')::UUID), (current_setting('test.student2')::UUID), (current_setting('test.student3_inactive')::UUID),
        (current_setting('test.teacherA')::UUID), (current_setting('test.teacherB')::UUID), (current_setting('test.admin')::UUID);
    
    INSERT INTO public.profiles (id, role) VALUES 
        (current_setting('test.student1')::UUID, 'student'), (current_setting('test.student2')::UUID, 'student'), (current_setting('test.student3_inactive')::UUID, 'student'),
        (current_setting('test.teacherA')::UUID, 'teacher'), (current_setting('test.teacherB')::UUID, 'teacher'),
        (current_setting('test.admin')::UUID, 'admin');

    INSERT INTO public.courses (id, title) VALUES (current_setting('test.course_id')::UUID, 'Test Course');
    INSERT INTO public.batches (id, name, course_id) VALUES 
        (current_setting('test.batchA')::UUID, 'Batch A', current_setting('test.course_id')::UUID), 
        (current_setting('test.batchB')::UUID, 'Batch B', current_setting('test.course_id')::UUID);

    INSERT INTO public.batch_teachers (batch_id, teacher_id) VALUES 
        (current_setting('test.batchA')::UUID, current_setting('test.teacherA')::UUID), 
        (current_setting('test.batchB')::UUID, current_setting('test.teacherB')::UUID);

    INSERT INTO public.enrollments (student_id, batch_id, status) VALUES 
        (current_setting('test.student1')::UUID, current_setting('test.batchA')::UUID, 'active'), 
        (current_setting('test.student2')::UUID, current_setting('test.batchB')::UUID, 'active'),
        (current_setting('test.student3_inactive')::UUID, current_setting('test.batchA')::UUID, 'cancelled');

    -- Seed Doubt B for Teacher B tests
    INSERT INTO public.doubts (id, student_id, batch_id, subject, question_text) 
    VALUES (current_setting('test.doubtB')::UUID, current_setting('test.student2')::UUID, current_setting('test.batchB')::UUID, 'Sci', 'Q2');
END $$;


-- ==============================================================================
-- POSITIVE TESTS
-- ==============================================================================
-- [TEST 1] Active student inserts into own batch
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student1')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student1'), true);
DO $$ DECLARE r INT; BEGIN
    INSERT INTO public.doubts (id, student_id, batch_id, subject, question_text)
    VALUES (current_setting('test.doubtA')::UUID, current_setting('test.student1')::UUID, current_setting('test.batchA')::UUID, 'Math', 'Q1');
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 1 THEN RAISE EXCEPTION 'TEST 1 FAILED: Expected 1 row affected'; END IF;
END $$;
RESET ROLE;

-- [TEST 2] Assigned teacher reads own-batch doubt
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE r INT; BEGIN
    PERFORM id FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 1 THEN RAISE EXCEPTION 'TEST 2 FAILED: Expected 1 row read'; END IF;
END $$;
RESET ROLE;

-- [TEST 3] Assigned teacher resolves own-batch doubt
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE r INT; BEGIN
    UPDATE public.doubts SET is_resolved = true, faculty_reply = 'Ans', faculty_name = 'T-A', resolved_by = current_setting('test.teacherA')::UUID, resolved_at = now() WHERE id = current_setting('test.doubtA')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 1 THEN RAISE EXCEPTION 'TEST 3 FAILED: Expected 1 row affected'; END IF;
END $$;
RESET ROLE;

-- [TEST 4] Admin reads globally
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.admin')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.admin'), true);
DO $$ DECLARE r INT; BEGIN
    PERFORM id FROM public.doubts;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r < 2 THEN RAISE EXCEPTION 'TEST 4 FAILED: Expected >= 2 rows read'; END IF;
END $$;
RESET ROLE;

-- [TEST 5] Admin resolves a doubt
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.admin')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.admin'), true);
DO $$ DECLARE r INT; BEGIN
    UPDATE public.doubts SET is_resolved = true, faculty_reply = 'Ans', faculty_name = 'Ad', resolved_by = current_setting('test.admin')::UUID, resolved_at = now() WHERE id = current_setting('test.doubtB')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 1 THEN RAISE EXCEPTION 'TEST 5 FAILED: Expected 1 row affected'; END IF;
END $$;
RESET ROLE;

-- ==============================================================================
-- NEGATIVE TESTS
-- ==============================================================================
-- [TEST 6] Student cannot insert into another batch
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student1')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student1'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN
        INSERT INTO public.doubts (id, student_id, batch_id, subject, question_text) VALUES (gen_random_uuid(), current_setting('test.student1')::UUID, current_setting('test.batchB')::UUID, 'Math', 'Q');
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%new row violates row-level security policy%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF;
    END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 6 FAILED: Insert succeeded'; END IF;
END $$;
RESET ROLE;

-- [TEST 7] Inactive student cannot insert
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student3_inactive')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student3_inactive'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN
        INSERT INTO public.doubts (id, student_id, batch_id, subject, question_text) VALUES (gen_random_uuid(), current_setting('test.student3_inactive')::UUID, current_setting('test.batchA')::UUID, 'Math', 'Q');
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%new row violates row-level security policy%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF;
    END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 7 FAILED: Insert succeeded'; END IF;
END $$;
RESET ROLE;

-- [TEST 8] Student cannot read another student's doubt
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student1')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student1'), true);
DO $$ DECLARE r INT; BEGIN
    PERFORM id FROM public.doubts WHERE id = current_setting('test.doubtB')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 0 THEN RAISE EXCEPTION 'TEST 8 FAILED: Expected 0 rows read'; END IF;
END $$;
RESET ROLE;

-- [TEST 9] Teacher A cannot read Teacher B's batch
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE r INT; BEGIN
    PERFORM id FROM public.doubts WHERE id = current_setting('test.doubtB')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 0 THEN RAISE EXCEPTION 'TEST 9 FAILED: Expected 0 rows read'; END IF;
END $$;
RESET ROLE;

-- [TEST 10] Teacher A cannot update Teacher B's batch
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE r INT; BEGIN
    UPDATE public.doubts SET subject = 'Hack' WHERE id = current_setting('test.doubtB')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 0 THEN RAISE EXCEPTION 'TEST 10 FAILED: Expected 0 rows affected'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN IF (SELECT subject FROM public.doubts WHERE id = current_setting('test.doubtB')::UUID) = 'Hack' THEN RAISE EXCEPTION 'TEST 10 FAILED: Row altered'; END IF; END $$;

-- -----------------------------------------------------
-- IMMUTABILITY & RESOLUTION TESTS (Tests 11-19 via Teacher A on Doubt A)
-- -----------------------------------------------------

-- [TEST 11] Teacher cannot change student_id
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET student_id = current_setting('test.student2')::UUID WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%student_id cannot be modified%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 11 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 11 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 12] Teacher cannot change batch_id
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET batch_id = current_setting('test.batchB')::UUID WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%batch_id cannot be modified%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 12 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 12 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 13] Teacher cannot change question_text
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET question_text = 'Hack' WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%question_text cannot be modified%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 13 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 13 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 14] Teacher cannot change subject
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET subject = 'Hack' WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%subject cannot be modified%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 14 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 14 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 15] Teacher cannot spoof resolved_by
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET resolved_by = current_setting('test.admin')::UUID WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%resolved_by must match%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 15 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 15 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 16] Teacher cannot resolve without faculty_reply
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET faculty_reply = NULL WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%faculty_reply must be provided%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 16 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 16 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 17] Teacher cannot resolve without faculty_name
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET faculty_name = ' ' WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%faculty_name must be provided%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 17 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 17 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 18] Teacher cannot resolve without resolved_at
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET resolved_at = NULL WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%resolved_at cannot be null%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 18 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 18 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 19] Teacher cannot create unresolved rows with resolution metadata
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.teacherA')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.teacherA'), true);
DO $$ DECLARE caught BOOLEAN := false; BEGIN
    BEGIN UPDATE public.doubts SET is_resolved = false WHERE id = current_setting('test.doubtA')::UUID;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM LIKE '%faculty_reply must be null%' THEN caught := true; ELSE RAISE EXCEPTION 'Unexpected error: %', SQLERRM; END IF; END;
    IF NOT caught THEN RAISE EXCEPTION 'TEST 19 FAILED'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 19 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 20] Student cannot update
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student1')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student1'), true);
DO $$ DECLARE r INT; BEGIN
    UPDATE public.doubts SET subject = 'Hack' WHERE id = current_setting('test.doubtA')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 0 THEN RAISE EXCEPTION 'TEST 20 FAILED: Expected 0 rows affected'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 20 FAILED: Target row modified.'; END IF; END $$;

-- [TEST 21] Student cannot delete
SET ROLE authenticated;
SELECT set_config('request.jwt.claims', format('{"sub": "%s", "role": "authenticated"}', current_setting('test.student1')), true);
SELECT set_config('request.jwt.claim.sub', current_setting('test.student1'), true);
DO $$ DECLARE r INT; BEGIN
    DELETE FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID;
    GET DIAGNOSTICS r = ROW_COUNT;
    IF r != 0 THEN RAISE EXCEPTION 'TEST 21 FAILED: Expected 0 rows affected'; END IF;
END $$;
RESET ROLE;
DO $$ DECLARE d public.doubts%ROWTYPE; BEGIN SELECT * INTO d FROM public.doubts WHERE id = current_setting('test.doubtA')::UUID; IF d.student_id != current_setting('test.student1')::UUID OR d.batch_id != current_setting('test.batchA')::UUID OR d.subject != 'Math' OR d.question_text != 'Q1' OR d.is_resolved != true OR d.faculty_name != 'T-A' THEN RAISE EXCEPTION 'POST-CONDITION 21 FAILED: Target row modified.'; END IF; END $$;

ROLLBACK;
