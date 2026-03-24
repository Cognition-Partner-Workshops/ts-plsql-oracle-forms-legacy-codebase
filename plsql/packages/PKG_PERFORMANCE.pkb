CREATE OR REPLACE PACKAGE BODY HRMS.PKG_PERFORMANCE AS
-- ============================================================================
-- PKG_PERFORMANCE - Performance Review Management Package Body
-- ============================================================================

    FUNCTION create_review_cycle(
        p_cycle_name         IN VARCHAR2,
        p_cycle_year         IN NUMBER,
        p_start_date         IN DATE,
        p_end_date           IN DATE,
        p_self_review_due    IN DATE DEFAULT NULL,
        p_manager_review_due IN DATE DEFAULT NULL,
        p_user               IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_cycle_id NUMBER;
    BEGIN
        SELECT SEQ_REVIEW_CYCLE.NEXTVAL INTO v_cycle_id FROM DUAL;

        INSERT INTO REVIEW_CYCLES (
            CYCLE_ID, CYCLE_NAME, CYCLE_YEAR, START_DATE, END_DATE,
            SELF_REVIEW_DUE, MANAGER_REVIEW_DUE,
            STATUS, CREATED_BY, CREATED_DATE
        ) VALUES (
            v_cycle_id, p_cycle_name, p_cycle_year, p_start_date, p_end_date,
            p_self_review_due, p_manager_review_due,
            'DRAFT', p_user, SYSDATE
        );

        PKG_AUDIT.log_action('REVIEW_CYCLES', v_cycle_id, 'INSERT', p_user);
        RETURN v_cycle_id;
    END create_review_cycle;

    PROCEDURE open_review_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE REVIEW_CYCLES SET
            STATUS = 'OPEN',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE CYCLE_ID = p_cycle_id
        AND STATUS = 'DRAFT';

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20401, 'Cannot open cycle - must be in DRAFT status');
        END IF;
    END open_review_cycle;

    PROCEDURE close_review_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE REVIEW_CYCLES SET
            STATUS = 'CLOSED',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE CYCLE_ID = p_cycle_id;
    END close_review_cycle;

    FUNCTION create_review(
        p_cycle_id        IN NUMBER,
        p_emp_id          IN NUMBER,
        p_reviewer_emp_id IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_review_id NUMBER;
    BEGIN
        SELECT SEQ_PERF_REVIEW.NEXTVAL INTO v_review_id FROM DUAL;

        INSERT INTO PERFORMANCE_REVIEWS (
            REVIEW_ID, CYCLE_ID, EMP_ID, REVIEWER_EMP_ID,
            REVIEW_TYPE, STATUS,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_review_id, p_cycle_id, p_emp_id, p_reviewer_emp_id,
            'ANNUAL', 'NOT_STARTED',
            p_user, SYSDATE
        );

        -- Notify employee
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => p_emp_id,
            p_type             => 'EMAIL',
            p_subject          => 'Performance Review Initiated',
            p_body             => 'Your annual performance review has been initiated. ' ||
                                  'Please complete your self-assessment.',
            p_user             => p_user
        );

        RETURN v_review_id;
    END create_review;

    PROCEDURE submit_self_assessment(
        p_review_id       IN NUMBER,
        p_self_assessment IN CLOB,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE PERFORMANCE_REVIEWS SET
            SELF_ASSESSMENT = p_self_assessment,
            STATUS = 'MANAGER_REVIEW',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REVIEW_ID = p_review_id
        AND STATUS IN ('NOT_STARTED', 'SELF_REVIEW');

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20402, 'Review not found or not in correct status');
        END IF;

        -- Notify manager
        DECLARE
            v_manager_id NUMBER;
        BEGIN
            SELECT REVIEWER_EMP_ID INTO v_manager_id
            FROM PERFORMANCE_REVIEWS
            WHERE REVIEW_ID = p_review_id;

            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => v_manager_id,
                p_type             => 'EMAIL',
                p_subject          => 'Self-Assessment Submitted - Ready for Manager Review',
                p_body             => 'An employee has completed their self-assessment. ' ||
                                      'Please proceed with the manager review.',
                p_user             => p_user
            );
        END;
    END submit_self_assessment;

    PROCEDURE submit_manager_review(
        p_review_id          IN NUMBER,
        p_overall_rating     IN NUMBER,
        p_manager_assessment IN CLOB,
        p_strengths          IN CLOB DEFAULT NULL,
        p_improvement_areas  IN CLOB DEFAULT NULL,
        p_development_plan   IN CLOB DEFAULT NULL,
        p_user               IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        IF p_overall_rating < 1.0 OR p_overall_rating > 5.0 THEN
            RAISE_APPLICATION_ERROR(-20403, 'Rating must be between 1.0 and 5.0');
        END IF;

        UPDATE PERFORMANCE_REVIEWS SET
            OVERALL_RATING = p_overall_rating,
            RATING_LABEL = CASE
                WHEN p_overall_rating >= 4.5 THEN 'Exceptional'
                WHEN p_overall_rating >= 3.5 THEN 'Exceeds Expectations'
                WHEN p_overall_rating >= 2.5 THEN 'Meets Expectations'
                WHEN p_overall_rating >= 1.5 THEN 'Needs Improvement'
                ELSE 'Unsatisfactory'
            END,
            MANAGER_ASSESSMENT = p_manager_assessment,
            STRENGTHS = p_strengths,
            AREAS_FOR_IMPROVEMENT = p_improvement_areas,
            DEVELOPMENT_PLAN = p_development_plan,
            STATUS = 'COMPLETED',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REVIEW_ID = p_review_id;

        -- Notify employee
        DECLARE
            v_emp_id NUMBER;
        BEGIN
            SELECT EMP_ID INTO v_emp_id
            FROM PERFORMANCE_REVIEWS
            WHERE REVIEW_ID = p_review_id;

            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => v_emp_id,
                p_type             => 'EMAIL',
                p_subject          => 'Performance Review Completed',
                p_body             => 'Your manager has completed your performance review. ' ||
                                      'Please review and acknowledge.',
                p_user             => p_user
            );
        END;
    END submit_manager_review;

    PROCEDURE acknowledge_review(
        p_review_id    IN NUMBER,
        p_emp_comments IN CLOB DEFAULT NULL,
        p_user         IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE PERFORMANCE_REVIEWS SET
            EMPLOYEE_COMMENTS = p_emp_comments,
            EMPLOYEE_ACK_DATE = SYSDATE,
            STATUS = 'ACKNOWLEDGED',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REVIEW_ID = p_review_id
        AND STATUS = 'COMPLETED';
    END acknowledge_review;

    FUNCTION add_goal(
        p_review_id        IN NUMBER,
        p_emp_id           IN NUMBER,
        p_goal_title       IN VARCHAR2,
        p_goal_description IN CLOB DEFAULT NULL,
        p_goal_category    IN VARCHAR2 DEFAULT 'BUSINESS',
        p_weight_pct       IN NUMBER DEFAULT 0,
        p_target_date      IN DATE DEFAULT NULL,
        p_user             IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_goal_id NUMBER;
    BEGIN
        SELECT SEQ_PERF_GOAL.NEXTVAL INTO v_goal_id FROM DUAL;

        INSERT INTO PERFORMANCE_GOALS (
            GOAL_ID, REVIEW_ID, EMP_ID, GOAL_TITLE,
            GOAL_DESCRIPTION, GOAL_CATEGORY, WEIGHT_PCT,
            TARGET_DATE, STATUS, PROGRESS_PCT,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_goal_id, p_review_id, p_emp_id, p_goal_title,
            p_goal_description, p_goal_category, p_weight_pct,
            p_target_date, 'NOT_STARTED', 0,
            p_user, SYSDATE
        );

        RETURN v_goal_id;
    END add_goal;

    PROCEDURE update_goal_progress(
        p_goal_id      IN NUMBER,
        p_progress_pct IN NUMBER,
        p_status       IN VARCHAR2 DEFAULT NULL,
        p_comments     IN CLOB DEFAULT NULL,
        p_user         IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE PERFORMANCE_GOALS SET
            PROGRESS_PCT = p_progress_pct,
            STATUS = NVL(p_status, CASE
                WHEN p_progress_pct >= 100 THEN 'COMPLETED'
                WHEN p_progress_pct > 0 THEN 'IN_PROGRESS'
                ELSE STATUS
            END),
            COMMENTS = NVL(p_comments, COMMENTS),
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE GOAL_ID = p_goal_id;
    END update_goal_progress;

    PROCEDURE get_team_reviews(
        p_cursor     OUT t_review_cursor,
        p_manager_id IN NUMBER,
        p_cycle_id   IN NUMBER
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT pr.REVIEW_ID, pr.EMP_ID,
                   e.FIRST_NAME || ' ' || e.LAST_NAME AS EMPLOYEE_NAME,
                   j.JOB_TITLE, d.DEPT_NAME,
                   pr.STATUS, pr.OVERALL_RATING, pr.RATING_LABEL
            FROM PERFORMANCE_REVIEWS pr
            JOIN EMPLOYEES e ON pr.EMP_ID = e.EMP_ID
            JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            WHERE pr.REVIEWER_EMP_ID = p_manager_id
            AND pr.CYCLE_ID = p_cycle_id
            ORDER BY e.LAST_NAME;
    END get_team_reviews;

    FUNCTION get_rating_distribution(
        p_cycle_id IN NUMBER,
        p_dept_id  IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT pr.RATING_LABEL, COUNT(*) AS COUNT,
                   ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PERCENTAGE
            FROM PERFORMANCE_REVIEWS pr
            JOIN EMPLOYEES e ON pr.EMP_ID = e.EMP_ID
            WHERE pr.CYCLE_ID = p_cycle_id
            AND pr.OVERALL_RATING IS NOT NULL
            AND (p_dept_id IS NULL OR e.DEPT_ID = p_dept_id)
            GROUP BY pr.RATING_LABEL
            ORDER BY MIN(pr.OVERALL_RATING) DESC;

        RETURN v_cursor;
    END get_rating_distribution;

    PROCEDURE generate_reviews_for_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    ) IS
        v_count NUMBER := 0;
    BEGIN
        FOR emp_rec IN (
            SELECT EMP_ID, MANAGER_EMP_ID
            FROM EMPLOYEES
            WHERE EMPLOYMENT_STATUS = 'ACTIVE'
            AND MANAGER_EMP_ID IS NOT NULL
        ) LOOP
            BEGIN
                DECLARE
                    v_review_id NUMBER;
                BEGIN
                    v_review_id := create_review(
                        p_cycle_id, emp_rec.EMP_ID, emp_rec.MANAGER_EMP_ID, p_user);
                    v_count := v_count + 1;
                END;
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    NULL; -- Review already exists
            END;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Generated ' || v_count || ' reviews for cycle ' || p_cycle_id);
    END generate_reviews_for_cycle;

END PKG_PERFORMANCE;
/
