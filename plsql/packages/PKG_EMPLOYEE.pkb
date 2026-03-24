CREATE OR REPLACE PACKAGE BODY HRMS.PKG_EMPLOYEE AS
-- ============================================================================
-- PKG_EMPLOYEE - Employee Management Package Body
-- ============================================================================

    -- Private constants
    c_emp_number_prefix  CONSTANT VARCHAR2(3) := 'EMP';
    c_max_hierarchy_depth CONSTANT NUMBER := 15;

    -- Private forward declarations
    PROCEDURE log_history(
        p_emp_id        IN NUMBER,
        p_change_type   IN VARCHAR2,
        p_effective_date IN DATE,
        p_old_dept_id   IN NUMBER DEFAULT NULL,
        p_new_dept_id   IN NUMBER DEFAULT NULL,
        p_old_job_id    IN NUMBER DEFAULT NULL,
        p_new_job_id    IN NUMBER DEFAULT NULL,
        p_old_manager   IN NUMBER DEFAULT NULL,
        p_new_manager   IN NUMBER DEFAULT NULL,
        p_old_salary    IN NUMBER DEFAULT NULL,
        p_new_salary    IN NUMBER DEFAULT NULL,
        p_old_location  IN VARCHAR2 DEFAULT NULL,
        p_new_location  IN VARCHAR2 DEFAULT NULL,
        p_reason_code   IN VARCHAR2 DEFAULT NULL,
        p_comments      IN VARCHAR2 DEFAULT NULL,
        p_user          IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE validate_dept(p_dept_id IN NUMBER);
    PROCEDURE validate_manager(p_manager_id IN NUMBER, p_emp_id IN NUMBER DEFAULT NULL);
    FUNCTION get_next_emp_id RETURN NUMBER;

    -- -----------------------------------------------------------------------
    -- generate_emp_number
    -- Generates next employee number: EMP-NNNNNN
    -- BUG: race condition under concurrent inserts - no SELECT FOR UPDATE
    -- -----------------------------------------------------------------------
    FUNCTION generate_emp_number RETURN VARCHAR2 IS
        v_max_num NUMBER;
        v_new_number VARCHAR2(20);
    BEGIN
        SELECT NVL(MAX(TO_NUMBER(SUBSTR(EMP_NUMBER, 5))), 0) + 1
        INTO v_max_num
        FROM EMPLOYEES
        WHERE EMP_NUMBER LIKE c_emp_number_prefix || '-%';

        v_new_number := c_emp_number_prefix || '-' || LPAD(v_max_num, 6, '0');

        RETURN v_new_number;
    EXCEPTION
        WHEN OTHERS THEN
            -- Fallback: use sequence-based number
            RETURN c_emp_number_prefix || '-' || LPAD(SEQ_EMPLOYEE.NEXTVAL, 6, '0');
    END generate_emp_number;

    -- -----------------------------------------------------------------------
    -- get_next_emp_id
    -- -----------------------------------------------------------------------
    FUNCTION get_next_emp_id RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT SEQ_EMPLOYEE.NEXTVAL INTO v_id FROM DUAL;
        RETURN v_id;
    END get_next_emp_id;

    -- -----------------------------------------------------------------------
    -- validate_dept
    -- -----------------------------------------------------------------------
    PROCEDURE validate_dept(p_dept_id IN NUMBER) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM DEPARTMENTS
        WHERE DEPT_ID = p_dept_id
        AND ACTIVE_FLAG = 'Y';

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Invalid or inactive department: ' || p_dept_id);
        END IF;
    END validate_dept;

    -- -----------------------------------------------------------------------
    -- validate_manager
    -- Checks manager exists and is active. Also prevents circular reporting.
    -- -----------------------------------------------------------------------
    PROCEDURE validate_manager(p_manager_id IN NUMBER, p_emp_id IN NUMBER DEFAULT NULL) IS
        v_count NUMBER;
        v_current_mgr NUMBER;
        v_depth NUMBER := 0;
    BEGIN
        IF p_manager_id IS NULL THEN
            RETURN;  -- NULL manager is valid (top-level employee)
        END IF;

        -- Check manager exists and is active
        SELECT COUNT(*)
        INTO v_count
        FROM EMPLOYEES
        WHERE EMP_ID = p_manager_id
        AND EMPLOYMENT_STATUS = 'ACTIVE';

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Invalid or inactive manager: ' || p_manager_id);
        END IF;

        -- Check for circular reporting (only if updating existing employee)
        IF p_emp_id IS NOT NULL THEN
            v_current_mgr := p_manager_id;
            WHILE v_current_mgr IS NOT NULL AND v_depth < c_max_hierarchy_depth LOOP
                IF v_current_mgr = p_emp_id THEN
                    RAISE_APPLICATION_ERROR(-20004,
                        'Circular reporting chain detected: Employee ' || p_emp_id ||
                        ' cannot report to ' || p_manager_id);
                END IF;

                BEGIN
                    SELECT MANAGER_EMP_ID
                    INTO v_current_mgr
                    FROM EMPLOYEES
                    WHERE EMP_ID = v_current_mgr;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_current_mgr := NULL;
                END;

                v_depth := v_depth + 1;
            END LOOP;
        END IF;
    END validate_manager;

    -- -----------------------------------------------------------------------
    -- log_history
    -- Records employee change history
    -- -----------------------------------------------------------------------
    PROCEDURE log_history(
        p_emp_id        IN NUMBER,
        p_change_type   IN VARCHAR2,
        p_effective_date IN DATE,
        p_old_dept_id   IN NUMBER DEFAULT NULL,
        p_new_dept_id   IN NUMBER DEFAULT NULL,
        p_old_job_id    IN NUMBER DEFAULT NULL,
        p_new_job_id    IN NUMBER DEFAULT NULL,
        p_old_manager   IN NUMBER DEFAULT NULL,
        p_new_manager   IN NUMBER DEFAULT NULL,
        p_old_salary    IN NUMBER DEFAULT NULL,
        p_new_salary    IN NUMBER DEFAULT NULL,
        p_old_location  IN VARCHAR2 DEFAULT NULL,
        p_new_location  IN VARCHAR2 DEFAULT NULL,
        p_reason_code   IN VARCHAR2 DEFAULT NULL,
        p_comments      IN VARCHAR2 DEFAULT NULL,
        p_user          IN VARCHAR2 DEFAULT USER
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO EMPLOYEE_HISTORY (
            HIST_ID, EMP_ID, CHANGE_TYPE, EFFECTIVE_DATE,
            OLD_DEPT_ID, NEW_DEPT_ID, OLD_JOB_ID, NEW_JOB_ID,
            OLD_MANAGER_ID, NEW_MANAGER_ID, OLD_SALARY, NEW_SALARY,
            OLD_LOCATION, NEW_LOCATION, REASON_CODE, COMMENTS,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_EMP_HISTORY.NEXTVAL, p_emp_id, p_change_type, p_effective_date,
            p_old_dept_id, p_new_dept_id, p_old_job_id, p_new_job_id,
            p_old_manager, p_new_manager, p_old_salary, p_new_salary,
            p_old_location, p_new_location, p_reason_code, p_comments,
            p_user, SYSDATE
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- History logging should never fail the main transaction
            ROLLBACK;
            IF g_debug_mode THEN
                DBMS_OUTPUT.PUT_LINE('WARNING: Failed to log history for EMP_ID=' ||
                    p_emp_id || ': ' || SQLERRM);
            END IF;
    END log_history;

    -- -----------------------------------------------------------------------
    -- create_employee
    -- -----------------------------------------------------------------------
    FUNCTION create_employee(
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_hire_date       IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_manager_emp_id  IN NUMBER DEFAULT NULL,
        p_location_code   IN VARCHAR2 DEFAULT NULL,
        p_employment_type IN VARCHAR2 DEFAULT 'FULL_TIME',
        p_base_salary     IN NUMBER DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_emp_id     NUMBER;
        v_emp_number VARCHAR2(20);
        v_location   VARCHAR2(10);
        v_grade_id   NUMBER;
    BEGIN
        -- Validate inputs
        IF p_first_name IS NULL OR p_last_name IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'First name and last name are required');
        END IF;

        validate_dept(p_dept_id);
        validate_manager(p_manager_emp_id);

        -- Validate job exists
        BEGIN
            SELECT GRADE_ID INTO v_grade_id
            FROM JOB_TITLES
            WHERE JOB_ID = p_job_id AND ACTIVE_FLAG = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20011, 'Invalid or inactive job: ' || p_job_id);
        END;

        -- Validate salary against grade range
        IF p_base_salary IS NOT NULL THEN
            DECLARE
                v_min NUMBER;
                v_max NUMBER;
            BEGIN
                SELECT MIN_SALARY, MAX_SALARY
                INTO v_min, v_max
                FROM JOB_GRADES
                WHERE GRADE_ID = v_grade_id;

                IF p_base_salary < v_min OR p_base_salary > v_max THEN
                    -- NOTE: This is a soft warning, not an error
                    -- Forms trigger WHEN-VALIDATE-ITEM shows warning dialog
                    -- but allows override with manager approval
                    IF g_debug_mode THEN
                        DBMS_OUTPUT.PUT_LINE('WARNING: Salary ' || p_base_salary ||
                            ' outside grade range [' || v_min || '-' || v_max || ']');
                    END IF;
                END IF;
            END;
        END IF;

        -- Default location from department if not specified
        IF p_location_code IS NULL THEN
            SELECT LOCATION_CODE INTO v_location
            FROM DEPARTMENTS
            WHERE DEPT_ID = p_dept_id;
        ELSE
            v_location := p_location_code;
        END IF;

        -- Generate IDs
        v_emp_id := get_next_emp_id();
        v_emp_number := generate_emp_number();

        -- Insert employee record
        INSERT INTO EMPLOYEES (
            EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, MANAGER_EMP_ID,
            LOCATION_CODE, EMPLOYMENT_TYPE, EMPLOYMENT_STATUS,
            EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_emp_id, v_emp_number, UPPER(TRIM(p_first_name)), UPPER(TRIM(p_last_name)),
            p_hire_date, p_dept_id, p_job_id, p_manager_emp_id,
            v_location, p_employment_type, 'ACTIVE',
            LOWER(TRIM(p_email)), 'Y',
            p_user, SYSDATE
        );

        -- Create initial salary record
        IF p_base_salary IS NOT NULL THEN
            -- NOTE: Circular dependency - calls PKG_PAYROLL.create_salary_record
            -- which in turn may call PKG_EMPLOYEE.is_active for validation
            PKG_PAYROLL.create_salary_record(
                p_emp_id         => v_emp_id,
                p_effective_date => p_hire_date,
                p_base_salary    => p_base_salary,
                p_change_reason  => 'NEW_HIRE',
                p_user           => p_user
            );
        END IF;

        -- Log history
        log_history(
            p_emp_id        => v_emp_id,
            p_change_type   => 'HIRE',
            p_effective_date => p_hire_date,
            p_new_dept_id   => p_dept_id,
            p_new_job_id    => p_job_id,
            p_new_manager   => p_manager_emp_id,
            p_new_salary    => p_base_salary,
            p_new_location  => v_location,
            p_user          => p_user
        );

        -- Audit trail
        PKG_AUDIT.log_action(
            p_table_name => 'EMPLOYEES',
            p_record_id  => v_emp_id,
            p_action     => 'INSERT',
            p_user       => p_user
        );

        -- Send welcome notification
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => v_emp_id,
            p_type             => 'EMAIL',
            p_subject          => 'Welcome to the Company',
            p_body             => 'Dear ' || p_first_name || ', Welcome aboard! ' ||
                                  'Your employee number is ' || v_emp_number || '.',
            p_user             => p_user
        );

        -- Notify manager
        IF p_manager_emp_id IS NOT NULL THEN
            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => p_manager_emp_id,
                p_type             => 'EMAIL',
                p_subject          => 'New Direct Report: ' || p_first_name || ' ' || p_last_name,
                p_body             => p_first_name || ' ' || p_last_name ||
                                      ' has been added as your direct report, starting ' ||
                                      TO_CHAR(p_hire_date, 'MM/DD/YYYY') || '.',
                p_user             => p_user
            );
        END IF;

        RETURN v_emp_id;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20002, 'Duplicate employee number generated. Please retry.');
        WHEN OTHERS THEN
            -- Log error details before re-raising
            PKG_COMMON.log_error(
                p_package  => 'PKG_EMPLOYEE',
                p_procedure => 'create_employee',
                p_message  => SQLERRM,
                p_user     => p_user
            );
            RAISE;
    END create_employee;

    -- -----------------------------------------------------------------------
    -- update_employee
    -- Updates only non-NULL parameters (partial update pattern)
    -- -----------------------------------------------------------------------
    PROCEDURE update_employee(
        p_emp_id          IN NUMBER,
        p_first_name      IN VARCHAR2 DEFAULT NULL,
        p_last_name       IN VARCHAR2 DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_phone_work      IN VARCHAR2 DEFAULT NULL,
        p_phone_mobile    IN VARCHAR2 DEFAULT NULL,
        p_address_line1   IN VARCHAR2 DEFAULT NULL,
        p_address_line2   IN VARCHAR2 DEFAULT NULL,
        p_city            IN VARCHAR2 DEFAULT NULL,
        p_state_province  IN VARCHAR2 DEFAULT NULL,
        p_postal_code     IN VARCHAR2 DEFAULT NULL,
        p_country_code    IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        IF NOT emp_exists(p_emp_id) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found: ' || p_emp_id);
        END IF;

        UPDATE EMPLOYEES SET
            FIRST_NAME     = NVL(UPPER(TRIM(p_first_name)), FIRST_NAME),
            LAST_NAME      = NVL(UPPER(TRIM(p_last_name)), LAST_NAME),
            EMAIL          = NVL(LOWER(TRIM(p_email)), EMAIL),
            PHONE_WORK     = NVL(p_phone_work, PHONE_WORK),
            PHONE_MOBILE   = NVL(p_phone_mobile, PHONE_MOBILE),
            ADDRESS_LINE1  = NVL(p_address_line1, ADDRESS_LINE1),
            ADDRESS_LINE2  = NVL(p_address_line2, ADDRESS_LINE2),
            CITY           = NVL(p_city, CITY),
            STATE_PROVINCE = NVL(p_state_province, STATE_PROVINCE),
            POSTAL_CODE    = NVL(p_postal_code, POSTAL_CODE),
            COUNTRY_CODE   = NVL(p_country_code, COUNTRY_CODE),
            MODIFIED_BY    = p_user,
            MODIFIED_DATE  = SYSDATE
        WHERE EMP_ID = p_emp_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee update failed: ' || p_emp_id);
        END IF;

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', p_user);
    END update_employee;

    -- -----------------------------------------------------------------------
    -- get_employee
    -- -----------------------------------------------------------------------
    FUNCTION get_employee(
        p_emp_id IN NUMBER
    ) RETURN t_emp_rec IS
        v_rec t_emp_rec;
    BEGIN
        SELECT e.EMP_ID, e.EMP_NUMBER, e.FIRST_NAME, e.LAST_NAME,
               e.HIRE_DATE, e.DEPT_ID, e.JOB_ID, e.MANAGER_EMP_ID,
               e.EMPLOYMENT_STATUS,
               (SELECT sr.BASE_SALARY
                FROM SALARY_RECORDS sr
                WHERE sr.EMP_ID = e.EMP_ID
                AND sr.ACTIVE_FLAG = 'Y'
                AND sr.EFFECTIVE_DATE <= SYSDATE
                AND (sr.END_DATE IS NULL OR sr.END_DATE > SYSDATE)
                AND ROWNUM = 1)
        INTO v_rec.emp_id, v_rec.emp_number, v_rec.first_name, v_rec.last_name,
             v_rec.hire_date, v_rec.dept_id, v_rec.job_id, v_rec.manager_emp_id,
             v_rec.employment_status, v_rec.base_salary
        FROM EMPLOYEES e
        WHERE e.EMP_ID = p_emp_id;

        RETURN v_rec;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found: ' || p_emp_id);
    END get_employee;

    -- -----------------------------------------------------------------------
    -- get_employee_by_number
    -- -----------------------------------------------------------------------
    FUNCTION get_employee_by_number(
        p_emp_number IN VARCHAR2
    ) RETURN t_emp_rec IS
        v_emp_id NUMBER;
    BEGIN
        SELECT EMP_ID INTO v_emp_id
        FROM EMPLOYEES
        WHERE EMP_NUMBER = p_emp_number;

        RETURN get_employee(v_emp_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found: ' || p_emp_number);
    END get_employee_by_number;

    -- -----------------------------------------------------------------------
    -- search_employees
    -- Dynamic search with optional filters
    -- BUG: SQL injection possible via p_last_name if called with unvalidated input
    -- (Forms LOV passes validated values, but direct calls are vulnerable)
    -- -----------------------------------------------------------------------
    PROCEDURE search_employees(
        p_cursor         OUT t_emp_cursor,
        p_last_name      IN VARCHAR2 DEFAULT NULL,
        p_first_name     IN VARCHAR2 DEFAULT NULL,
        p_dept_id        IN NUMBER DEFAULT NULL,
        p_status         IN VARCHAR2 DEFAULT NULL,
        p_location_code  IN VARCHAR2 DEFAULT NULL,
        p_hire_date_from IN DATE DEFAULT NULL,
        p_hire_date_to   IN DATE DEFAULT NULL
    ) IS
        v_sql VARCHAR2(4000);
    BEGIN
        v_sql := 'SELECT e.EMP_ID, e.EMP_NUMBER, e.FIRST_NAME, e.LAST_NAME, ' ||
                 'e.HIRE_DATE, e.DEPT_ID, d.DEPT_NAME, j.JOB_TITLE, ' ||
                 'e.EMPLOYMENT_STATUS, e.LOCATION_CODE ' ||
                 'FROM EMPLOYEES e ' ||
                 'JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID ' ||
                 'JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID ' ||
                 'WHERE 1=1 ';

        IF p_last_name IS NOT NULL THEN
            -- VULNERABILITY: String concatenation instead of bind variable
            v_sql := v_sql || 'AND UPPER(e.LAST_NAME) LIKE UPPER(''' || p_last_name || '%'') ';
        END IF;

        IF p_first_name IS NOT NULL THEN
            v_sql := v_sql || 'AND UPPER(e.FIRST_NAME) LIKE UPPER(''' || p_first_name || '%'') ';
        END IF;

        IF p_dept_id IS NOT NULL THEN
            v_sql := v_sql || 'AND e.DEPT_ID = ' || p_dept_id || ' ';
        END IF;

        IF p_status IS NOT NULL THEN
            v_sql := v_sql || 'AND e.EMPLOYMENT_STATUS = ''' || p_status || ''' ';
        END IF;

        IF p_location_code IS NOT NULL THEN
            v_sql := v_sql || 'AND e.LOCATION_CODE = ''' || p_location_code || ''' ';
        END IF;

        IF p_hire_date_from IS NOT NULL THEN
            v_sql := v_sql || 'AND e.HIRE_DATE >= TO_DATE(''' ||
                     TO_CHAR(p_hire_date_from, 'YYYY-MM-DD') || ''', ''YYYY-MM-DD'') ';
        END IF;

        IF p_hire_date_to IS NOT NULL THEN
            v_sql := v_sql || 'AND e.HIRE_DATE <= TO_DATE(''' ||
                     TO_CHAR(p_hire_date_to, 'YYYY-MM-DD') || ''', ''YYYY-MM-DD'') ';
        END IF;

        v_sql := v_sql || 'ORDER BY e.LAST_NAME, e.FIRST_NAME';

        OPEN p_cursor FOR v_sql;
    END search_employees;

    -- -----------------------------------------------------------------------
    -- transfer_employee
    -- -----------------------------------------------------------------------
    PROCEDURE transfer_employee(
        p_emp_id          IN NUMBER,
        p_new_dept_id     IN NUMBER,
        p_new_job_id      IN NUMBER DEFAULT NULL,
        p_new_manager_id  IN NUMBER DEFAULT NULL,
        p_new_location    IN VARCHAR2 DEFAULT NULL,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_reason_code     IN VARCHAR2 DEFAULT NULL,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_old_rec EMPLOYEES%ROWTYPE;
        v_new_job_id NUMBER;
        v_new_location VARCHAR2(10);
    BEGIN
        -- Get current record
        SELECT * INTO v_old_rec
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id
        FOR UPDATE NOWAIT;

        IF v_old_rec.EMPLOYMENT_STATUS != 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20012,
                'Cannot transfer non-active employee. Status: ' || v_old_rec.EMPLOYMENT_STATUS);
        END IF;

        -- Validate new department
        validate_dept(p_new_dept_id);

        -- Default job and location
        v_new_job_id := NVL(p_new_job_id, v_old_rec.JOB_ID);
        v_new_location := NVL(p_new_location, v_old_rec.LOCATION_CODE);

        -- Validate new manager if specified
        IF p_new_manager_id IS NOT NULL THEN
            validate_manager(p_new_manager_id, p_emp_id);
        END IF;

        -- Update employee
        UPDATE EMPLOYEES SET
            DEPT_ID        = p_new_dept_id,
            JOB_ID         = v_new_job_id,
            MANAGER_EMP_ID = NVL(p_new_manager_id, MANAGER_EMP_ID),
            LOCATION_CODE  = v_new_location,
            MODIFIED_BY    = p_user,
            MODIFIED_DATE  = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'TRANSFER',
            p_effective_date => p_effective_date,
            p_old_dept_id    => v_old_rec.DEPT_ID,
            p_new_dept_id    => p_new_dept_id,
            p_old_job_id     => v_old_rec.JOB_ID,
            p_new_job_id     => v_new_job_id,
            p_old_manager    => v_old_rec.MANAGER_EMP_ID,
            p_new_manager    => NVL(p_new_manager_id, v_old_rec.MANAGER_EMP_ID),
            p_old_location   => v_old_rec.LOCATION_CODE,
            p_new_location   => v_new_location,
            p_reason_code    => p_reason_code,
            p_comments       => p_comments,
            p_user           => p_user
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', p_user);

    EXCEPTION
        WHEN OTHERS THEN
            PKG_COMMON.log_error('PKG_EMPLOYEE', 'transfer_employee', SQLERRM, p_user);
            RAISE;
    END transfer_employee;

    -- -----------------------------------------------------------------------
    -- promote_employee
    -- -----------------------------------------------------------------------
    PROCEDURE promote_employee(
        p_emp_id          IN NUMBER,
        p_new_job_id      IN NUMBER,
        p_new_salary      IN NUMBER,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_old_job_id NUMBER;
        v_old_salary NUMBER;
    BEGIN
        SELECT JOB_ID INTO v_old_job_id
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        -- Get current salary
        BEGIN
            SELECT BASE_SALARY INTO v_old_salary
            FROM SALARY_RECORDS
            WHERE EMP_ID = p_emp_id
            AND ACTIVE_FLAG = 'Y'
            AND ROWNUM = 1
            ORDER BY EFFECTIVE_DATE DESC;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_old_salary := 0;
        END;

        -- Update job
        UPDATE EMPLOYEES SET
            JOB_ID        = p_new_job_id,
            MODIFIED_BY   = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- Create new salary record
        PKG_PAYROLL.create_salary_record(
            p_emp_id         => p_emp_id,
            p_effective_date => p_effective_date,
            p_base_salary    => p_new_salary,
            p_change_reason  => 'PROMOTION',
            p_change_pct     => CASE WHEN v_old_salary > 0
                                     THEN ROUND(((p_new_salary - v_old_salary) / v_old_salary) * 100, 2)
                                     ELSE NULL END,
            p_user           => p_user
        );

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'PROMOTION',
            p_effective_date => p_effective_date,
            p_old_job_id     => v_old_job_id,
            p_new_job_id     => p_new_job_id,
            p_old_salary     => v_old_salary,
            p_new_salary     => p_new_salary,
            p_comments       => p_comments,
            p_user           => p_user
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', p_user);
    END promote_employee;

    -- -----------------------------------------------------------------------
    -- terminate_employee
    -- -----------------------------------------------------------------------
    PROCEDURE terminate_employee(
        p_emp_id           IN NUMBER,
        p_termination_date IN DATE,
        p_reason           IN VARCHAR2,
        p_comments         IN VARCHAR2 DEFAULT NULL,
        p_user             IN VARCHAR2 DEFAULT USER
    ) IS
        v_emp EMPLOYEES%ROWTYPE;
        v_pending_leave NUMBER;
    BEGIN
        SELECT * INTO v_emp
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id
        FOR UPDATE;

        IF v_emp.EMPLOYMENT_STATUS = 'TERMINATED' THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Employee ' || p_emp_id || ' is already terminated');
        END IF;

        -- Check for pending leave requests
        SELECT COUNT(*) INTO v_pending_leave
        FROM LEAVE_REQUESTS
        WHERE EMP_ID = p_emp_id
        AND STATUS = 'PENDING';

        IF v_pending_leave > 0 THEN
            -- Auto-cancel pending leave requests
            UPDATE LEAVE_REQUESTS
            SET STATUS = 'CANCELLED',
                CANCEL_REASON = 'Auto-cancelled due to termination',
                CANCELLED_DATE = SYSDATE,
                MODIFIED_BY = p_user,
                MODIFIED_DATE = SYSDATE
            WHERE EMP_ID = p_emp_id
            AND STATUS = 'PENDING';
        END IF;

        -- Update employee status
        UPDATE EMPLOYEES SET
            EMPLOYMENT_STATUS  = 'TERMINATED',
            TERMINATION_DATE   = p_termination_date,
            TERMINATION_REASON = p_reason,
            ACTIVE_FLAG        = 'N',
            MODIFIED_BY        = p_user,
            MODIFIED_DATE      = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- End current salary record
        UPDATE SALARY_RECORDS
        SET END_DATE = p_termination_date,
            ACTIVE_FLAG = 'N',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y';

        -- Deactivate pay elements
        UPDATE EMPLOYEE_PAY_ELEMENTS
        SET END_DATE = p_termination_date,
            ACTIVE_FLAG = 'N',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y';

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'TERMINATION',
            p_effective_date => p_termination_date,
            p_reason_code    => p_reason,
            p_comments       => p_comments,
            p_user           => p_user
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', p_user);

        -- Send notifications
        IF v_emp.MANAGER_EMP_ID IS NOT NULL THEN
            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => v_emp.MANAGER_EMP_ID,
                p_type             => 'EMAIL',
                p_subject          => 'Employee Termination: ' || v_emp.FIRST_NAME || ' ' || v_emp.LAST_NAME,
                p_body             => v_emp.FIRST_NAME || ' ' || v_emp.LAST_NAME ||
                                      ' termination effective ' || TO_CHAR(p_termination_date, 'MM/DD/YYYY'),
                p_user             => p_user
            );
        END IF;

        -- TODO: Integrate with benefits system to trigger COBRA
        -- TODO: Revoke system access via PKG_SECURITY
        -- TODO: Calculate final pay via PKG_PAYROLL.calculate_final_pay

    EXCEPTION
        WHEN OTHERS THEN
            PKG_COMMON.log_error('PKG_EMPLOYEE', 'terminate_employee', SQLERRM, p_user);
            RAISE;
    END terminate_employee;

    -- -----------------------------------------------------------------------
    -- rehire_employee
    -- -----------------------------------------------------------------------
    PROCEDURE rehire_employee(
        p_emp_id          IN NUMBER,
        p_rehire_date     IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_base_salary     IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        validate_dept(p_dept_id);

        UPDATE EMPLOYEES SET
            EMPLOYMENT_STATUS  = 'ACTIVE',
            HIRE_DATE          = p_rehire_date,
            TERMINATION_DATE   = NULL,
            TERMINATION_REASON = NULL,
            DEPT_ID            = p_dept_id,
            JOB_ID             = p_job_id,
            ACTIVE_FLAG        = 'Y',
            MODIFIED_BY        = p_user,
            MODIFIED_DATE      = SYSDATE
        WHERE EMP_ID = p_emp_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found for rehire: ' || p_emp_id);
        END IF;

        -- Create new salary record
        PKG_PAYROLL.create_salary_record(
            p_emp_id         => p_emp_id,
            p_effective_date => p_rehire_date,
            p_base_salary    => p_base_salary,
            p_change_reason  => 'REHIRE',
            p_user           => p_user
        );

        log_history(p_emp_id, 'REHIRE', p_rehire_date,
            p_new_dept_id => p_dept_id,
            p_new_job_id  => p_job_id,
            p_new_salary  => p_base_salary,
            p_user        => p_user);

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', p_user);
    END rehire_employee;

    -- -----------------------------------------------------------------------
    -- get_direct_reports
    -- -----------------------------------------------------------------------
    FUNCTION get_direct_reports(
        p_manager_emp_id IN NUMBER
    ) RETURN t_emp_id_table IS
        v_result t_emp_id_table;
        v_idx    BINARY_INTEGER := 0;
    BEGIN
        FOR r IN (
            SELECT EMP_ID
            FROM EMPLOYEES
            WHERE MANAGER_EMP_ID = p_manager_emp_id
            AND EMPLOYMENT_STATUS = 'ACTIVE'
            ORDER BY LAST_NAME, FIRST_NAME
        ) LOOP
            v_idx := v_idx + 1;
            v_result(v_idx) := r.EMP_ID;
        END LOOP;

        RETURN v_result;
    END get_direct_reports;

    -- -----------------------------------------------------------------------
    -- get_org_chart
    -- Recursive query - known to time out for orgs with >500 employees
    -- -----------------------------------------------------------------------
    FUNCTION get_org_chart(
        p_root_emp_id IN NUMBER,
        p_max_depth   IN NUMBER DEFAULT 10
    ) RETURN t_emp_cursor IS
        v_cursor t_emp_cursor;
    BEGIN
        OPEN v_cursor FOR
            SELECT LEVEL AS depth,
                   EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
                   DEPT_ID, JOB_ID, MANAGER_EMP_ID
            FROM EMPLOYEES
            WHERE EMPLOYMENT_STATUS = 'ACTIVE'
            START WITH EMP_ID = p_root_emp_id
            CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID
            AND LEVEL <= p_max_depth
            ORDER SIBLINGS BY LAST_NAME, FIRST_NAME;

        RETURN v_cursor;
    END get_org_chart;

    -- -----------------------------------------------------------------------
    -- get_headcount_by_dept
    -- -----------------------------------------------------------------------
    FUNCTION get_headcount_by_dept(
        p_dept_id    IN NUMBER DEFAULT NULL,
        p_as_of_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM EMPLOYEES
        WHERE (p_dept_id IS NULL OR DEPT_ID = p_dept_id)
        AND EMPLOYMENT_STATUS = 'ACTIVE'
        AND HIRE_DATE <= p_as_of_date
        AND (TERMINATION_DATE IS NULL OR TERMINATION_DATE > p_as_of_date);

        RETURN v_count;
    END get_headcount_by_dept;

    -- -----------------------------------------------------------------------
    -- get_tenure_years
    -- -----------------------------------------------------------------------
    FUNCTION get_tenure_years(
        p_emp_id IN NUMBER
    ) RETURN NUMBER IS
        v_hire_date DATE;
        v_end_date  DATE;
    BEGIN
        SELECT HIRE_DATE, NVL(TERMINATION_DATE, SYSDATE)
        INTO v_hire_date, v_end_date
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN ROUND(MONTHS_BETWEEN(v_end_date, v_hire_date) / 12, 1);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_tenure_years;

    -- -----------------------------------------------------------------------
    -- is_active
    -- -----------------------------------------------------------------------
    FUNCTION is_active(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT EMPLOYMENT_STATUS
        INTO v_status
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN v_status = 'ACTIVE';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END is_active;

    -- -----------------------------------------------------------------------
    -- validate_employee
    -- -----------------------------------------------------------------------
    FUNCTION validate_employee(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_emp EMPLOYEES%ROWTYPE;
    BEGIN
        SELECT * INTO v_emp FROM EMPLOYEES WHERE EMP_ID = p_emp_id;

        -- Basic validations
        IF v_emp.FIRST_NAME IS NULL OR v_emp.LAST_NAME IS NULL THEN
            RETURN FALSE;
        END IF;

        IF v_emp.HIRE_DATE IS NULL THEN
            RETURN FALSE;
        END IF;

        IF v_emp.EMPLOYMENT_STATUS = 'ACTIVE' AND v_emp.ACTIVE_FLAG != 'Y' THEN
            RETURN FALSE;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END validate_employee;

    -- -----------------------------------------------------------------------
    -- emp_exists
    -- -----------------------------------------------------------------------
    FUNCTION emp_exists(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN v_count > 0;
    END emp_exists;

    -- -----------------------------------------------------------------------
    -- set_session_context
    -- -----------------------------------------------------------------------
    PROCEDURE set_session_context(
        p_user    IN VARCHAR2,
        p_emp_id  IN NUMBER
    ) IS
    BEGIN
        g_current_user := p_user;
        g_current_emp_id := p_emp_id;

        SELECT DEPT_ID INTO g_current_dept_id
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            g_current_dept_id := NULL;
    END set_session_context;

END PKG_EMPLOYEE;
/
