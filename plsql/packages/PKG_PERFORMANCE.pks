CREATE OR REPLACE PACKAGE HRMS.PKG_PERFORMANCE AS
-- ============================================================================
-- PKG_PERFORMANCE - Performance Review Management Package
-- Review cycles, goal tracking, ratings, calibration
--
-- Dependencies: PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
-- Called by: HRMS_PERFORMANCE form, batch calibration job
-- ============================================================================

    TYPE t_review_cursor IS REF CURSOR;

    FUNCTION create_review_cycle(
        p_cycle_name         IN VARCHAR2,
        p_cycle_year         IN NUMBER,
        p_start_date         IN DATE,
        p_end_date           IN DATE,
        p_self_review_due    IN DATE DEFAULT NULL,
        p_manager_review_due IN DATE DEFAULT NULL,
        p_user               IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE open_review_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE close_review_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    );

    FUNCTION create_review(
        p_cycle_id        IN NUMBER,
        p_emp_id          IN NUMBER,
        p_reviewer_emp_id IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE submit_self_assessment(
        p_review_id      IN NUMBER,
        p_self_assessment IN CLOB,
        p_user           IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE submit_manager_review(
        p_review_id          IN NUMBER,
        p_overall_rating     IN NUMBER,
        p_manager_assessment IN CLOB,
        p_strengths          IN CLOB DEFAULT NULL,
        p_improvement_areas  IN CLOB DEFAULT NULL,
        p_development_plan   IN CLOB DEFAULT NULL,
        p_user               IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE acknowledge_review(
        p_review_id       IN NUMBER,
        p_emp_comments    IN CLOB DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    FUNCTION add_goal(
        p_review_id        IN NUMBER,
        p_emp_id           IN NUMBER,
        p_goal_title       IN VARCHAR2,
        p_goal_description IN CLOB DEFAULT NULL,
        p_goal_category    IN VARCHAR2 DEFAULT 'BUSINESS',
        p_weight_pct       IN NUMBER DEFAULT 0,
        p_target_date      IN DATE DEFAULT NULL,
        p_user             IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE update_goal_progress(
        p_goal_id     IN NUMBER,
        p_progress_pct IN NUMBER,
        p_status      IN VARCHAR2 DEFAULT NULL,
        p_comments    IN CLOB DEFAULT NULL,
        p_user        IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE get_team_reviews(
        p_cursor     OUT t_review_cursor,
        p_manager_id IN NUMBER,
        p_cycle_id   IN NUMBER
    );

    FUNCTION get_rating_distribution(
        p_cycle_id IN NUMBER,
        p_dept_id  IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    PROCEDURE generate_reviews_for_cycle(
        p_cycle_id IN NUMBER,
        p_user     IN VARCHAR2 DEFAULT USER
    );

END PKG_PERFORMANCE;
/
