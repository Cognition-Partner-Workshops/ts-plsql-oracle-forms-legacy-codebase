CREATE OR REPLACE PACKAGE HRMS.PKG_LEAVE AS
-- ============================================================================
-- PKG_LEAVE - Leave Management Package
-- Leave requests, approvals, balance tracking, accrual processing
--
-- Dependencies: PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
-- Called by: HRMS_LEAVE form, self-service portal, batch accrual job
-- Known issues:
--   - Overlapping leave detection does not account for half-day requests
--   - Carryover expiry job sometimes double-expires if run twice on same day
--   - Holiday detection only checks exact date match, not observed dates
-- ============================================================================

    e_insufficient_balance   EXCEPTION;
    e_overlapping_leave      EXCEPTION;
    e_invalid_leave_type     EXCEPTION;
    e_approval_error         EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_insufficient_balance, -20201);
    PRAGMA EXCEPTION_INIT(e_overlapping_leave,    -20202);
    PRAGMA EXCEPTION_INIT(e_invalid_leave_type,   -20203);
    PRAGMA EXCEPTION_INIT(e_approval_error,       -20204);

    TYPE t_leave_cursor IS REF CURSOR;

    -- -----------------------------------------------------------------------
    -- Leave Requests
    -- -----------------------------------------------------------------------
    FUNCTION submit_leave_request(
        p_emp_id        IN NUMBER,
        p_leave_type_id IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_half_day_flag IN CHAR DEFAULT 'N',
        p_half_day_period IN VARCHAR2 DEFAULT NULL,
        p_reason        IN VARCHAR2 DEFAULT NULL,
        p_user          IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER;

    PROCEDURE approve_leave_request(
        p_request_id      IN NUMBER,
        p_approver_emp_id IN NUMBER,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE reject_leave_request(
        p_request_id      IN NUMBER,
        p_approver_emp_id IN NUMBER,
        p_comments        IN VARCHAR2,
        p_user            IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE cancel_leave_request(
        p_request_id IN NUMBER,
        p_reason     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Balance Management
    -- -----------------------------------------------------------------------
    FUNCTION get_leave_balance(
        p_emp_id        IN NUMBER,
        p_leave_type_id IN NUMBER,
        p_year          IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;

    PROCEDURE adjust_leave_balance(
        p_emp_id        IN NUMBER,
        p_leave_type_id IN NUMBER,
        p_adjustment    IN NUMBER,
        p_reason        IN VARCHAR2,
        p_user          IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE initialize_balances(
        p_emp_id IN NUMBER,
        p_year   IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Accrual Processing (batch)
    -- -----------------------------------------------------------------------
    PROCEDURE run_monthly_accrual(
        p_accrual_date IN DATE DEFAULT SYSDATE,
        p_user         IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE process_carryover(
        p_year IN NUMBER,
        p_user IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE expire_carryover(
        p_user IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Queries
    -- -----------------------------------------------------------------------
    PROCEDURE get_pending_requests(
        p_cursor        OUT t_leave_cursor,
        p_approver_id   IN NUMBER
    );

    PROCEDURE get_team_calendar(
        p_cursor        OUT t_leave_cursor,
        p_manager_id    IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE
    );

    FUNCTION calculate_business_days(
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_location_code IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    FUNCTION check_leave_overlap(
        p_emp_id     IN NUMBER,
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_exclude_request_id IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;

END PKG_LEAVE;
/
