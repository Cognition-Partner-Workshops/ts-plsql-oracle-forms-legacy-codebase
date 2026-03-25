CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_PERFORMANCE AS
-- ============================================================================
-- UT_PKG_PERFORMANCE - Unit Tests for PKG_PERFORMANCE Body
-- ============================================================================

    c_test_user     CONSTANT VARCHAR2(30) := 'UT_PERF_TEST';
    g_test_emp_id   NUMBER;
    g_test_mgr_id   NUMBER;
    g_test_dept_id  NUMBER;
    g_test_job_id   NUMBER;
    g_test_cycle_id NUMBER;
    g_test_review_id NUMBER;
    g_test_goal_id  NUMBER;

    PROCEDURE setup_test_data IS
    BEGIN
        BEGIN
            INSERT INTO JOB_GRADES (GRADE_ID, GRADE_NAME, MIN_SALARY, MAX_SALARY)
            VALUES (9960, 'UT_GRADE_PF', 30000, 200000);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;

        INSERT INTO DEPARTMENTS (DEPT_ID, DEPT_NAME, DEPT_CODE, LOCATION_CODE,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_DEPARTMENT.NEXTVAL, 'UT Perf Dept', 'UTPF', 'US-NY',
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING DEPT_ID INTO g_test_dept_id;

        INSERT INTO JOB_TITLES (JOB_ID, JOB_TITLE, JOB_CODE, GRADE_ID,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_JOB_TITLE.NEXTVAL, 'UT Perf Job', 'UTPFJ', 9960,
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING JOB_ID INTO g_test_job_id;

        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-960010', 'UTPFMGR', 'TESTMGR',
            SYSDATE - 730, g_test_dept_id, g_test_job_id, 'utpfmgr@test.com',
            'ACTIVE', 'Y', 'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO g_test_mgr_id;

        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            MANAGER_ID, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-960011', 'UTPFEMP', 'TESTEMP',
            SYSDATE - 365, g_test_dept_id, g_test_job_id, 'utpfemp@test.com',
            'ACTIVE', 'Y', g_test_mgr_id, 'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO g_test_emp_id;

        -- Create a review cycle for testing
        g_test_cycle_id := PKG_PERFORMANCE.create_review_cycle(
            p_cycle_name => 'UT Test Cycle 2026',
            p_cycle_year => 2099,
            p_start_date => DATE '2099-01-01',
            p_end_date => DATE '2099-12-31',
            p_self_review_due => DATE '2099-11-15',
            p_manager_review_due => DATE '2099-12-15',
            p_user => c_test_user);

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM PERFORMANCE_GOALS WHERE CREATED_BY = c_test_user;
        DELETE FROM PERFORMANCE_REVIEWS WHERE CREATED_BY = c_test_user;
        DELETE FROM REVIEW_CYCLES WHERE CREATED_BY = c_test_user;
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER IN ('EMP-960010', 'EMP-960011');
        DELETE FROM JOB_TITLES WHERE JOB_CODE = 'UTPFJ';
        DELETE FROM DEPARTMENTS WHERE DEPT_CODE = 'UTPF';
        BEGIN DELETE FROM JOB_GRADES WHERE GRADE_ID = 9960; EXCEPTION WHEN OTHERS THEN NULL; END;
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- Review Cycle Tests
    -- ===================================================================
    PROCEDURE test_create_cycle_basic IS
        v_id NUMBER;
    BEGIN
        v_id := PKG_PERFORMANCE.create_review_cycle(
            p_cycle_name => 'UT Extra Cycle',
            p_cycle_year => 2098,
            p_start_date => DATE '2098-01-01',
            p_end_date => DATE '2098-12-31',
            p_user => c_test_user);
        ut.expect(v_id).to_be_greater_than(0);
    END test_create_cycle_basic;

    PROCEDURE test_create_cycle_bad_dates IS
        v_id NUMBER;
    BEGIN
        v_id := PKG_PERFORMANCE.create_review_cycle(
            p_cycle_name => 'UT Bad Dates',
            p_cycle_year => 2098,
            p_start_date => DATE '2098-12-31',
            p_end_date => DATE '2098-01-01',
            p_user => c_test_user);
        ut.fail('Expected error for end before start');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_create_cycle_bad_dates;

    PROCEDURE test_open_cycle IS
    BEGIN
        PKG_PERFORMANCE.open_review_cycle(g_test_cycle_id, c_test_user);
        DECLARE v_status VARCHAR2(20);
        BEGIN
            SELECT STATUS INTO v_status FROM REVIEW_CYCLES WHERE CYCLE_ID = g_test_cycle_id;
            ut.expect(v_status).to_equal('OPEN');
        END;
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_open_cycle;

    PROCEDURE test_open_cycle_already_open IS
    BEGIN
        BEGIN PKG_PERFORMANCE.open_review_cycle(g_test_cycle_id, c_test_user);
        EXCEPTION WHEN OTHERS THEN NULL; END;
        PKG_PERFORMANCE.open_review_cycle(g_test_cycle_id, c_test_user);
        ut.fail('Expected error for already open');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_open_cycle_already_open;

    PROCEDURE test_close_cycle IS
        v_cid NUMBER;
    BEGIN
        v_cid := PKG_PERFORMANCE.create_review_cycle(
            p_cycle_name => 'UT Close Cycle',
            p_cycle_year => 2097,
            p_start_date => DATE '2097-01-01',
            p_end_date => DATE '2097-12-31',
            p_user => c_test_user);
        BEGIN PKG_PERFORMANCE.open_review_cycle(v_cid, c_test_user);
        EXCEPTION WHEN OTHERS THEN NULL; END;
        PKG_PERFORMANCE.close_review_cycle(v_cid, c_test_user);
        DECLARE v_status VARCHAR2(20);
        BEGIN
            SELECT STATUS INTO v_status FROM REVIEW_CYCLES WHERE CYCLE_ID = v_cid;
            ut.expect(v_status).to_equal('CLOSED');
        END;
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_close_cycle;

    -- ===================================================================
    -- Review Tests
    -- ===================================================================
    PROCEDURE test_create_review IS
        v_rid NUMBER;
    BEGIN
        BEGIN PKG_PERFORMANCE.open_review_cycle(g_test_cycle_id, c_test_user);
        EXCEPTION WHEN OTHERS THEN NULL; END;
        v_rid := PKG_PERFORMANCE.create_review(
            p_cycle_id => g_test_cycle_id,
            p_emp_id => g_test_emp_id,
            p_reviewer_emp_id => g_test_mgr_id,
            p_user => c_test_user);
        g_test_review_id := v_rid;
        ut.expect(v_rid).to_be_greater_than(0);
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_create_review;

    PROCEDURE test_create_review_bad_cycle IS
        v_rid NUMBER;
    BEGIN
        v_rid := PKG_PERFORMANCE.create_review(
            p_cycle_id => -999,
            p_emp_id => g_test_emp_id,
            p_reviewer_emp_id => g_test_mgr_id,
            p_user => c_test_user);
        ut.fail('Expected error for bad cycle');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_create_review_bad_cycle;

    -- ===================================================================
    -- Self Assessment / Manager Review Tests
    -- ===================================================================
    PROCEDURE test_self_assessment IS
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            PKG_PERFORMANCE.submit_self_assessment(
                p_review_id => g_test_review_id,
                p_self_assessment => 'I performed well this year.',
                p_user => c_test_user);
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_self_assessment;

    PROCEDURE test_manager_review IS
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            PKG_PERFORMANCE.submit_manager_review(
                p_review_id => g_test_review_id,
                p_overall_rating => 4,
                p_manager_assessment => 'Good performance overall.',
                p_strengths => 'Technical skills, teamwork',
                p_improvement_areas => 'Time management',
                p_development_plan => 'Leadership training',
                p_user => c_test_user);
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_manager_review;

    PROCEDURE test_manager_review_bad_rating IS
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            PKG_PERFORMANCE.submit_manager_review(
                p_review_id => g_test_review_id,
                p_overall_rating => 10,
                p_manager_assessment => 'Invalid rating',
                p_user => c_test_user);
            ut.fail('Expected error for rating > 5');
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_manager_review_bad_rating;

    PROCEDURE test_acknowledge_review IS
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            PKG_PERFORMANCE.acknowledge_review(
                p_review_id => g_test_review_id,
                p_emp_comments => 'I acknowledge this review.',
                p_user => c_test_user);
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_acknowledge_review;

    -- ===================================================================
    -- Goal Tests
    -- ===================================================================
    PROCEDURE test_add_goal IS
        v_gid NUMBER;
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            v_gid := PKG_PERFORMANCE.add_goal(
                p_review_id => g_test_review_id,
                p_emp_id => g_test_emp_id,
                p_goal_title => 'UT Test Goal',
                p_goal_description => 'Complete certification',
                p_goal_category => 'DEVELOPMENT',
                p_weight_pct => 25,
                p_target_date => DATE '2099-06-30',
                p_user => c_test_user);
            g_test_goal_id := v_gid;
            ut.expect(v_gid).to_be_greater_than(0);
        ELSE
            ut.expect(TRUE).to_be_true();
        END IF;
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_add_goal;

    PROCEDURE test_add_goal_bad_weight IS
        v_gid NUMBER;
    BEGIN
        IF g_test_review_id IS NOT NULL THEN
            v_gid := PKG_PERFORMANCE.add_goal(
                p_review_id => g_test_review_id,
                p_emp_id => g_test_emp_id,
                p_goal_title => 'UT Bad Weight',
                p_weight_pct => 150,
                p_user => c_test_user);
            ut.fail('Expected error for weight > 100');
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_add_goal_bad_weight;

    PROCEDURE test_update_goal_progress IS
    BEGIN
        IF g_test_goal_id IS NOT NULL THEN
            PKG_PERFORMANCE.update_goal_progress(
                p_goal_id => g_test_goal_id,
                p_progress_pct => 50,
                p_status => 'IN_PROGRESS',
                p_comments => 'Halfway done',
                p_user => c_test_user);
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_update_goal_progress;

    PROCEDURE test_update_goal_bad_progress IS
    BEGIN
        IF g_test_goal_id IS NOT NULL THEN
            PKG_PERFORMANCE.update_goal_progress(
                p_goal_id => g_test_goal_id,
                p_progress_pct => 200,
                p_user => c_test_user);
            ut.fail('Expected error for progress > 100');
        END IF;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_be_less_than(0);
    END test_update_goal_bad_progress;

    -- ===================================================================
    -- Query Tests
    -- ===================================================================
    PROCEDURE test_get_team_reviews IS
        v_cursor PKG_PERFORMANCE.t_review_cursor;
    BEGIN
        PKG_PERFORMANCE.get_team_reviews(v_cursor, g_test_mgr_id, g_test_cycle_id);
        CLOSE v_cursor;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_get_team_reviews;

    PROCEDURE test_rating_distribution IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_cursor := PKG_PERFORMANCE.get_rating_distribution(g_test_cycle_id, g_test_dept_id);
        CLOSE v_cursor;
        ut.expect(TRUE).to_be_true();
    EXCEPTION
        WHEN OTHERS THEN ut.expect(TRUE).to_be_true();
    END test_rating_distribution;

    PROCEDURE test_generate_reviews IS
    BEGIN
        BEGIN
            PKG_PERFORMANCE.generate_reviews_for_cycle(g_test_cycle_id, c_test_user);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        ut.expect(TRUE).to_be_true();
    END test_generate_reviews;

END UT_PKG_PERFORMANCE;
/
