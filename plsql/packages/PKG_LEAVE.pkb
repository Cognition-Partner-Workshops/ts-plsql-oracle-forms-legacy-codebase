CREATE OR REPLACE PACKAGE BODY HRMS.PKG_LEAVE AS
-- ============================================================================
-- PKG_LEAVE - Leave Management Package Body
-- ============================================================================

    -- -----------------------------------------------------------------------
    -- calculate_business_days
    -- Counts weekdays between two dates, excluding holidays
    -- BUG: Does not handle "observed" holidays (e.g., if July 4 falls on
    -- Saturday, the observed Friday is not excluded)
    -- -----------------------------------------------------------------------
    FUNCTION calculate_business_days(
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_location_code IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        v_count NUMBER := 0;
        v_date  DATE := TRUNC(p_start_date);
        v_holiday_count NUMBER;
    BEGIN
        WHILE v_date <= TRUNC(p_end_date) LOOP
            -- Skip weekends
            IF TO_CHAR(v_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN') NOT IN ('SAT', 'SUN') THEN
                -- Check if it's a holiday
                SELECT COUNT(*) INTO v_holiday_count
                FROM HOLIDAYS
                WHERE HOLIDAY_DATE = v_date
                AND ACTIVE_FLAG = 'Y'
                AND (LOCATION_CODE IS NULL OR LOCATION_CODE = p_location_code);

                IF v_holiday_count = 0 THEN
                    v_count := v_count + 1;
                END IF;
            END IF;

            v_date := v_date + 1;
        END LOOP;

        RETURN v_count;
    END calculate_business_days;

    -- -----------------------------------------------------------------------
    -- check_leave_overlap
    -- -----------------------------------------------------------------------
    FUNCTION check_leave_overlap(
        p_emp_id     IN NUMBER,
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_exclude_request_id IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM LEAVE_REQUESTS
        WHERE EMP_ID = p_emp_id
        AND STATUS IN ('PENDING', 'APPROVED')
        AND (p_exclude_request_id IS NULL OR REQUEST_ID != p_exclude_request_id)
        AND START_DATE <= p_end_date
        AND END_DATE >= p_start_date;

        RETURN v_count > 0;
    END check_leave_overlap;

    -- -----------------------------------------------------------------------
    -- submit_leave_request
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
    ) RETURN NUMBER IS
        v_request_id    NUMBER;
        v_total_days    NUMBER;
        v_balance       NUMBER;
        v_leave_type    LEAVE_TYPES%ROWTYPE;
        v_emp_rec       EMPLOYEES%ROWTYPE;
        v_manager_id    NUMBER;
    BEGIN
        -- Validate employee
        BEGIN
            SELECT * INTO v_emp_rec
            FROM EMPLOYEES
            WHERE EMP_ID = p_emp_id
            AND EMPLOYMENT_STATUS = 'ACTIVE';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Employee not found or not active: ' || p_emp_id);
        END;

        -- Validate leave type
        BEGIN
            SELECT * INTO v_leave_type
            FROM LEAVE_TYPES
            WHERE LEAVE_TYPE_ID = p_leave_type_id
            AND ACTIVE_FLAG = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20203, 'Invalid leave type: ' || p_leave_type_id);
        END;

        -- Check minimum tenure
        IF v_leave_type.MIN_TENURE_DAYS > 0 THEN
            IF SYSDATE - v_emp_rec.HIRE_DATE < v_leave_type.MIN_TENURE_DAYS THEN
                RAISE_APPLICATION_ERROR(-20203,
                    'Minimum tenure of ' || v_leave_type.MIN_TENURE_DAYS ||
                    ' days not met for leave type: ' || v_leave_type.LEAVE_TYPE_NAME);
            END IF;
        END IF;

        -- Validate dates
        IF p_start_date > p_end_date THEN
            RAISE_APPLICATION_ERROR(-20210, 'Start date must be before or equal to end date');
        END IF;

        IF p_start_date < TRUNC(SYSDATE) THEN
            -- Allow backdated requests up to 5 days
            IF TRUNC(SYSDATE) - p_start_date > 5 THEN
                RAISE_APPLICATION_ERROR(-20211,
                    'Cannot submit leave requests more than 5 days in the past');
            END IF;
        END IF;

        -- Calculate total business days
        IF p_half_day_flag = 'Y' THEN
            v_total_days := 0.5;
        ELSE
            v_total_days := calculate_business_days(
                p_start_date, p_end_date, v_emp_rec.LOCATION_CODE);
        END IF;

        IF v_total_days <= 0 THEN
            RAISE_APPLICATION_ERROR(-20212, 'No business days in the selected range');
        END IF;

        -- Check for overlapping leave
        IF check_leave_overlap(p_emp_id, p_start_date, p_end_date) THEN
            RAISE_APPLICATION_ERROR(-20202,
                'Leave request overlaps with an existing request');
        END IF;

        -- Check balance (only for accrual-based leave types)
        IF v_leave_type.ACCRUAL_FLAG = 'Y' THEN
            v_balance := get_leave_balance(p_emp_id, p_leave_type_id);
            IF v_balance < v_total_days THEN
                RAISE_APPLICATION_ERROR(-20201,
                    'Insufficient leave balance. Available: ' || v_balance ||
                    ', Requested: ' || v_total_days);
            END IF;
        END IF;

        -- Create request
        SELECT SEQ_LEAVE_REQUEST.NEXTVAL INTO v_request_id FROM DUAL;

        -- Get manager for approval routing
        v_manager_id := v_emp_rec.MANAGER_EMP_ID;

        INSERT INTO LEAVE_REQUESTS (
            REQUEST_ID, EMP_ID, LEAVE_TYPE_ID, START_DATE, END_DATE,
            TOTAL_DAYS, HALF_DAY_FLAG, HALF_DAY_PERIOD,
            STATUS, REASON, APPROVER_EMP_ID,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_request_id, p_emp_id, p_leave_type_id, p_start_date, p_end_date,
            v_total_days, p_half_day_flag, p_half_day_period,
            CASE WHEN v_leave_type.REQUIRES_APPROVAL = 'Y' THEN 'PENDING' ELSE 'APPROVED' END,
            p_reason, v_manager_id,
            p_user, SYSDATE
        );

        -- Update pending balance
        UPDATE LEAVE_BALANCES
        SET PENDING = PENDING + v_total_days,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND LEAVE_TYPE_ID = p_leave_type_id
        AND CALENDAR_YEAR = EXTRACT(YEAR FROM p_start_date);

        -- Notify manager
        IF v_manager_id IS NOT NULL AND v_leave_type.REQUIRES_APPROVAL = 'Y' THEN
            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => v_manager_id,
                p_type             => 'EMAIL',
                p_subject          => 'Leave Request Pending Approval',
                p_body             => v_emp_rec.FIRST_NAME || ' ' || v_emp_rec.LAST_NAME ||
                                      ' has requested ' || v_total_days || ' day(s) of ' ||
                                      v_leave_type.LEAVE_TYPE_NAME || ' from ' ||
                                      TO_CHAR(p_start_date, 'MM/DD/YYYY') || ' to ' ||
                                      TO_CHAR(p_end_date, 'MM/DD/YYYY') || '.',
                p_user             => p_user
            );
        END IF;

        -- Auto-approve if no approval required
        IF v_leave_type.REQUIRES_APPROVAL = 'N' THEN
            approve_leave_request(v_request_id, NULL, 'Auto-approved', p_user);
        END IF;

        PKG_AUDIT.log_action('LEAVE_REQUESTS', v_request_id, 'INSERT', p_user);

        RETURN v_request_id;
    END submit_leave_request;

    -- -----------------------------------------------------------------------
    -- approve_leave_request
    -- -----------------------------------------------------------------------
    PROCEDURE approve_leave_request(
        p_request_id      IN NUMBER,
        p_approver_emp_id IN NUMBER,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_request LEAVE_REQUESTS%ROWTYPE;
    BEGIN
        SELECT * INTO v_request
        FROM LEAVE_REQUESTS
        WHERE REQUEST_ID = p_request_id
        FOR UPDATE;

        IF v_request.STATUS != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20204,
                'Cannot approve request in status: ' || v_request.STATUS);
        END IF;

        -- Update request
        UPDATE LEAVE_REQUESTS SET
            STATUS = 'APPROVED',
            APPROVER_EMP_ID = p_approver_emp_id,
            APPROVAL_DATE = SYSDATE,
            APPROVAL_COMMENTS = p_comments,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REQUEST_ID = p_request_id;

        -- Move from pending to used
        UPDATE LEAVE_BALANCES SET
            PENDING = PENDING - v_request.TOTAL_DAYS,
            USED = USED + v_request.TOTAL_DAYS,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = v_request.EMP_ID
        AND LEAVE_TYPE_ID = v_request.LEAVE_TYPE_ID
        AND CALENDAR_YEAR = EXTRACT(YEAR FROM v_request.START_DATE);

        -- Notify employee
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => v_request.EMP_ID,
            p_type             => 'EMAIL',
            p_subject          => 'Leave Request Approved',
            p_body             => 'Your leave request from ' ||
                                  TO_CHAR(v_request.START_DATE, 'MM/DD/YYYY') || ' to ' ||
                                  TO_CHAR(v_request.END_DATE, 'MM/DD/YYYY') ||
                                  ' has been approved.',
            p_user             => p_user
        );

        PKG_AUDIT.log_action('LEAVE_REQUESTS', p_request_id, 'UPDATE', p_user);
    END approve_leave_request;

    -- -----------------------------------------------------------------------
    -- reject_leave_request
    -- -----------------------------------------------------------------------
    PROCEDURE reject_leave_request(
        p_request_id      IN NUMBER,
        p_approver_emp_id IN NUMBER,
        p_comments        IN VARCHAR2,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_request LEAVE_REQUESTS%ROWTYPE;
    BEGIN
        SELECT * INTO v_request
        FROM LEAVE_REQUESTS
        WHERE REQUEST_ID = p_request_id
        FOR UPDATE;

        IF v_request.STATUS != 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20204,
                'Cannot reject request in status: ' || v_request.STATUS);
        END IF;

        UPDATE LEAVE_REQUESTS SET
            STATUS = 'REJECTED',
            APPROVER_EMP_ID = p_approver_emp_id,
            APPROVAL_DATE = SYSDATE,
            APPROVAL_COMMENTS = p_comments,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REQUEST_ID = p_request_id;

        -- Release pending balance
        UPDATE LEAVE_BALANCES SET
            PENDING = PENDING - v_request.TOTAL_DAYS,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = v_request.EMP_ID
        AND LEAVE_TYPE_ID = v_request.LEAVE_TYPE_ID
        AND CALENDAR_YEAR = EXTRACT(YEAR FROM v_request.START_DATE);

        -- Notify employee
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => v_request.EMP_ID,
            p_type             => 'EMAIL',
            p_subject          => 'Leave Request Rejected',
            p_body             => 'Your leave request has been rejected. Reason: ' || p_comments,
            p_user             => p_user
        );

        PKG_AUDIT.log_action('LEAVE_REQUESTS', p_request_id, 'UPDATE', p_user);
    END reject_leave_request;

    -- -----------------------------------------------------------------------
    -- cancel_leave_request
    -- -----------------------------------------------------------------------
    PROCEDURE cancel_leave_request(
        p_request_id IN NUMBER,
        p_reason     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER
    ) IS
        v_request LEAVE_REQUESTS%ROWTYPE;
    BEGIN
        SELECT * INTO v_request
        FROM LEAVE_REQUESTS
        WHERE REQUEST_ID = p_request_id
        FOR UPDATE;

        IF v_request.STATUS NOT IN ('PENDING', 'APPROVED') THEN
            RAISE_APPLICATION_ERROR(-20204,
                'Cannot cancel request in status: ' || v_request.STATUS);
        END IF;

        UPDATE LEAVE_REQUESTS SET
            STATUS = 'CANCELLED',
            CANCEL_REASON = p_reason,
            CANCELLED_DATE = SYSDATE,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE REQUEST_ID = p_request_id;

        -- Restore balance
        IF v_request.STATUS = 'PENDING' THEN
            UPDATE LEAVE_BALANCES SET
                PENDING = PENDING - v_request.TOTAL_DAYS,
                MODIFIED_BY = p_user,
                MODIFIED_DATE = SYSDATE
            WHERE EMP_ID = v_request.EMP_ID
            AND LEAVE_TYPE_ID = v_request.LEAVE_TYPE_ID
            AND CALENDAR_YEAR = EXTRACT(YEAR FROM v_request.START_DATE);
        ELSIF v_request.STATUS = 'APPROVED' THEN
            UPDATE LEAVE_BALANCES SET
                USED = USED - v_request.TOTAL_DAYS,
                MODIFIED_BY = p_user,
                MODIFIED_DATE = SYSDATE
            WHERE EMP_ID = v_request.EMP_ID
            AND LEAVE_TYPE_ID = v_request.LEAVE_TYPE_ID
            AND CALENDAR_YEAR = EXTRACT(YEAR FROM v_request.START_DATE);
        END IF;

        PKG_AUDIT.log_action('LEAVE_REQUESTS', p_request_id, 'UPDATE', p_user);
    END cancel_leave_request;

    -- -----------------------------------------------------------------------
    -- get_leave_balance
    -- -----------------------------------------------------------------------
    FUNCTION get_leave_balance(
        p_emp_id        IN NUMBER,
        p_leave_type_id IN NUMBER,
        p_year          IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_balance NUMBER;
    BEGIN
        SELECT OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT - PENDING
        INTO v_balance
        FROM LEAVE_BALANCES
        WHERE EMP_ID = p_emp_id
        AND LEAVE_TYPE_ID = p_leave_type_id
        AND CALENDAR_YEAR = p_year;

        RETURN NVL(v_balance, 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END get_leave_balance;

    -- -----------------------------------------------------------------------
    -- adjust_leave_balance
    -- -----------------------------------------------------------------------
    PROCEDURE adjust_leave_balance(
        p_emp_id        IN NUMBER,
        p_leave_type_id IN NUMBER,
        p_adjustment    IN NUMBER,
        p_reason        IN VARCHAR2,
        p_user          IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE LEAVE_BALANCES SET
            ADJUSTMENT = ADJUSTMENT + p_adjustment,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND LEAVE_TYPE_ID = p_leave_type_id
        AND CALENDAR_YEAR = EXTRACT(YEAR FROM SYSDATE);

        IF SQL%ROWCOUNT = 0 THEN
            -- Create balance record if it doesn't exist
            initialize_balances(p_emp_id, EXTRACT(YEAR FROM SYSDATE), p_user);
            -- Retry
            UPDATE LEAVE_BALANCES SET
                ADJUSTMENT = ADJUSTMENT + p_adjustment,
                MODIFIED_BY = p_user,
                MODIFIED_DATE = SYSDATE
            WHERE EMP_ID = p_emp_id
            AND LEAVE_TYPE_ID = p_leave_type_id
            AND CALENDAR_YEAR = EXTRACT(YEAR FROM SYSDATE);
        END IF;

        PKG_AUDIT.log_action('LEAVE_BALANCES', p_emp_id, 'UPDATE', p_user);
    END adjust_leave_balance;

    -- -----------------------------------------------------------------------
    -- initialize_balances
    -- Creates balance records for all leave types for an employee/year
    -- -----------------------------------------------------------------------
    PROCEDURE initialize_balances(
        p_emp_id IN NUMBER,
        p_year   IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        FOR lt IN (
            SELECT LEAVE_TYPE_ID FROM LEAVE_TYPES WHERE ACTIVE_FLAG = 'Y'
        ) LOOP
            BEGIN
                INSERT INTO LEAVE_BALANCES (
                    BALANCE_ID, EMP_ID, LEAVE_TYPE_ID, CALENDAR_YEAR,
                    OPENING_BALANCE, ACCRUED, USED, ADJUSTMENT, PENDING,
                    CREATED_BY, CREATED_DATE
                ) VALUES (
                    SEQ_LEAVE_BALANCE.NEXTVAL, p_emp_id, lt.LEAVE_TYPE_ID, p_year,
                    0, 0, 0, 0, 0,
                    p_user, SYSDATE
                );
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    NULL; -- Already exists, skip
            END;
        END LOOP;
    END initialize_balances;

    -- -----------------------------------------------------------------------
    -- run_monthly_accrual
    -- Batch job: accrues leave for all active employees
    -- Typically scheduled via DBMS_SCHEDULER on the 1st of each month
    -- -----------------------------------------------------------------------
    PROCEDURE run_monthly_accrual(
        p_accrual_date IN DATE DEFAULT SYSDATE,
        p_user         IN VARCHAR2 DEFAULT USER
    ) IS
        v_accrued NUMBER := 0;
        v_total_employees NUMBER := 0;
        v_total_accrued NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Starting monthly leave accrual for ' ||
            TO_CHAR(p_accrual_date, 'YYYY-MM'));

        FOR emp_rec IN (
            SELECT e.EMP_ID, e.HIRE_DATE, e.LOCATION_CODE
            FROM EMPLOYEES e
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND e.ACTIVE_FLAG = 'Y'
        ) LOOP
            v_total_employees := v_total_employees + 1;

            FOR lt_rec IN (
                SELECT LEAVE_TYPE_ID, ACCRUAL_RATE, ACCRUAL_FREQUENCY,
                       MAX_BALANCE, MIN_TENURE_DAYS
                FROM LEAVE_TYPES
                WHERE ACTIVE_FLAG = 'Y'
                AND ACCRUAL_FLAG = 'Y'
                AND ACCRUAL_FREQUENCY = 'MONTHLY'
            ) LOOP
                -- Check tenure requirement
                IF TRUNC(p_accrual_date) - emp_rec.HIRE_DATE >= lt_rec.MIN_TENURE_DAYS THEN
                    -- Check max balance
                    DECLARE
                        v_current_balance NUMBER;
                    BEGIN
                        v_current_balance := get_leave_balance(
                            emp_rec.EMP_ID, lt_rec.LEAVE_TYPE_ID,
                            EXTRACT(YEAR FROM p_accrual_date));

                        IF lt_rec.MAX_BALANCE IS NULL OR
                           v_current_balance + lt_rec.ACCRUAL_RATE <= lt_rec.MAX_BALANCE THEN
                            v_accrued := lt_rec.ACCRUAL_RATE;
                        ELSE
                            v_accrued := GREATEST(0, lt_rec.MAX_BALANCE - v_current_balance);
                        END IF;

                        IF v_accrued > 0 THEN
                            -- Update balance
                            UPDATE LEAVE_BALANCES SET
                                ACCRUED = ACCRUED + v_accrued,
                                MODIFIED_BY = p_user,
                                MODIFIED_DATE = SYSDATE
                            WHERE EMP_ID = emp_rec.EMP_ID
                            AND LEAVE_TYPE_ID = lt_rec.LEAVE_TYPE_ID
                            AND CALENDAR_YEAR = EXTRACT(YEAR FROM p_accrual_date);

                            IF SQL%ROWCOUNT = 0 THEN
                                -- Initialize and retry
                                initialize_balances(emp_rec.EMP_ID,
                                    EXTRACT(YEAR FROM p_accrual_date), p_user);
                                UPDATE LEAVE_BALANCES SET
                                    ACCRUED = v_accrued,
                                    MODIFIED_BY = p_user,
                                    MODIFIED_DATE = SYSDATE
                                WHERE EMP_ID = emp_rec.EMP_ID
                                AND LEAVE_TYPE_ID = lt_rec.LEAVE_TYPE_ID
                                AND CALENDAR_YEAR = EXTRACT(YEAR FROM p_accrual_date);
                            END IF;

                            -- Log accrual
                            INSERT INTO LEAVE_ACCRUAL_LOG (
                                ACCRUAL_ID, EMP_ID, LEAVE_TYPE_ID, ACCRUAL_DATE,
                                ACCRUAL_AMOUNT, CREATED_BY, CREATED_DATE
                            ) VALUES (
                                SEQ_LEAVE_ACCRUAL.NEXTVAL, emp_rec.EMP_ID,
                                lt_rec.LEAVE_TYPE_ID, p_accrual_date,
                                v_accrued, p_user, SYSDATE
                            );

                            v_total_accrued := v_total_accrued + v_accrued;
                        END IF;
                    END;
                END IF;
            END LOOP;

            -- Commit every 100 employees
            IF MOD(v_total_employees, 100) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Accrual complete: ' || v_total_employees ||
            ' employees, ' || v_total_accrued || ' total days accrued');
    END run_monthly_accrual;

    -- -----------------------------------------------------------------------
    -- process_carryover
    -- Runs at year-end to carry over unused leave to next year
    -- -----------------------------------------------------------------------
    PROCEDURE process_carryover(
        p_year IN NUMBER,
        p_user IN VARCHAR2 DEFAULT USER
    ) IS
        v_next_year NUMBER := p_year + 1;
        v_carryover NUMBER;
    BEGIN
        FOR bal_rec IN (
            SELECT lb.EMP_ID, lb.LEAVE_TYPE_ID,
                   lb.OPENING_BALANCE + lb.ACCRUED - lb.USED + lb.ADJUSTMENT AS REMAINING,
                   lt.CARRYOVER_MAX, lt.CARRYOVER_EXPIRY
            FROM LEAVE_BALANCES lb
            JOIN LEAVE_TYPES lt ON lb.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
            WHERE lb.CALENDAR_YEAR = p_year
            AND lb.OPENING_BALANCE + lb.ACCRUED - lb.USED + lb.ADJUSTMENT > 0
        ) LOOP
            v_carryover := bal_rec.REMAINING;

            -- Cap at carryover max
            IF bal_rec.CARRYOVER_MAX IS NOT NULL THEN
                v_carryover := LEAST(v_carryover, bal_rec.CARRYOVER_MAX);
            END IF;

            IF v_carryover > 0 THEN
                -- Initialize next year's balance if needed
                initialize_balances(bal_rec.EMP_ID, v_next_year, p_user);

                -- Set carryover
                UPDATE LEAVE_BALANCES SET
                    CARRYOVER_FROM_PREV = v_carryover,
                    OPENING_BALANCE = v_carryover,
                    CARRYOVER_EXPIRY_DT = CASE
                        WHEN bal_rec.CARRYOVER_EXPIRY IS NOT NULL
                        THEN ADD_MONTHS(TO_DATE(v_next_year || '-01-01', 'YYYY-MM-DD'),
                                       bal_rec.CARRYOVER_EXPIRY)
                        ELSE NULL END,
                    MODIFIED_BY = p_user,
                    MODIFIED_DATE = SYSDATE
                WHERE EMP_ID = bal_rec.EMP_ID
                AND LEAVE_TYPE_ID = bal_rec.LEAVE_TYPE_ID
                AND CALENDAR_YEAR = v_next_year;
            END IF;
        END LOOP;

        COMMIT;
    END process_carryover;

    -- -----------------------------------------------------------------------
    -- expire_carryover
    -- Removes expired carryover balances
    -- BUG: If run twice on same day, can double-subtract
    -- -----------------------------------------------------------------------
    PROCEDURE expire_carryover(
        p_user IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE LEAVE_BALANCES SET
            ADJUSTMENT = ADJUSTMENT - CARRYOVER_FROM_PREV,
            CARRYOVER_FROM_PREV = 0,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE CARRYOVER_EXPIRY_DT <= TRUNC(SYSDATE)
        AND CARRYOVER_FROM_PREV > 0;

        COMMIT;
    END expire_carryover;

    -- -----------------------------------------------------------------------
    -- get_pending_requests
    -- -----------------------------------------------------------------------
    PROCEDURE get_pending_requests(
        p_cursor      OUT t_leave_cursor,
        p_approver_id IN NUMBER
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT lr.REQUEST_ID, lr.EMP_ID,
                   e.FIRST_NAME || ' ' || e.LAST_NAME AS EMPLOYEE_NAME,
                   lt.LEAVE_TYPE_NAME,
                   lr.START_DATE, lr.END_DATE, lr.TOTAL_DAYS,
                   lr.REASON, lr.CREATED_DATE
            FROM LEAVE_REQUESTS lr
            JOIN EMPLOYEES e ON lr.EMP_ID = e.EMP_ID
            JOIN LEAVE_TYPES lt ON lr.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
            WHERE lr.STATUS = 'PENDING'
            AND lr.APPROVER_EMP_ID = p_approver_id
            ORDER BY lr.CREATED_DATE;
    END get_pending_requests;

    -- -----------------------------------------------------------------------
    -- get_team_calendar
    -- -----------------------------------------------------------------------
    PROCEDURE get_team_calendar(
        p_cursor     OUT t_leave_cursor,
        p_manager_id IN NUMBER,
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT e.EMP_ID, e.FIRST_NAME || ' ' || e.LAST_NAME AS EMPLOYEE_NAME,
                   lt.LEAVE_TYPE_NAME, lt.LEAVE_TYPE_CODE,
                   lr.START_DATE, lr.END_DATE, lr.TOTAL_DAYS,
                   lr.STATUS, lr.HALF_DAY_FLAG
            FROM LEAVE_REQUESTS lr
            JOIN EMPLOYEES e ON lr.EMP_ID = e.EMP_ID
            JOIN LEAVE_TYPES lt ON lr.LEAVE_TYPE_ID = lt.LEAVE_TYPE_ID
            WHERE e.MANAGER_EMP_ID = p_manager_id
            AND lr.STATUS IN ('APPROVED', 'TAKEN')
            AND lr.START_DATE <= p_end_date
            AND lr.END_DATE >= p_start_date
            ORDER BY lr.START_DATE, e.LAST_NAME;
    END get_team_calendar;

END PKG_LEAVE;
/
