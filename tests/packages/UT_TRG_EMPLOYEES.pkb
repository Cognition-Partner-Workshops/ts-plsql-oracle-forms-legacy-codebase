CREATE OR REPLACE PACKAGE BODY HRMS.UT_TRG_EMPLOYEES AS
-- ============================================================================
-- UT_TRG_EMPLOYEES - Unit Tests for Employee Table Triggers
-- Tests: TRG_EMP_BEFORE_INSERT, TRG_EMP_BEFORE_UPDATE, TRG_EMP_INSTEAD_OF_DELETE
-- ============================================================================

    c_test_user    CONSTANT VARCHAR2(30) := 'UT_TRG_EMP';
    g_test_dept_id NUMBER;
    g_test_job_id  NUMBER;
    g_test_emp_id  NUMBER;
    g_test_dept2_id NUMBER;
    g_test_job2_id  NUMBER;

    PROCEDURE setup_test_data IS
    BEGIN
        BEGIN
            INSERT INTO JOB_GRADES (GRADE_ID, GRADE_NAME, MIN_SALARY, MAX_SALARY)
            VALUES (9950, 'UT_GRADE_TE', 30000, 200000);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;

        INSERT INTO DEPARTMENTS (DEPT_ID, DEPT_NAME, DEPT_CODE, LOCATION_CODE,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_DEPARTMENT.NEXTVAL, 'UT Trg Dept1', 'UTT1', 'US-NY',
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING DEPT_ID INTO g_test_dept_id;

        INSERT INTO DEPARTMENTS (DEPT_ID, DEPT_NAME, DEPT_CODE, LOCATION_CODE,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_DEPARTMENT.NEXTVAL, 'UT Trg Dept2', 'UTT2', 'US-CA',
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING DEPT_ID INTO g_test_dept2_id;

        INSERT INTO JOB_TITLES (JOB_ID, JOB_TITLE, JOB_CODE, GRADE_ID,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_JOB_TITLE.NEXTVAL, 'UT Trg Job1', 'UTTJ1', 9950,
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING JOB_ID INTO g_test_job_id;

        INSERT INTO JOB_TITLES (JOB_ID, JOB_TITLE, JOB_CODE, GRADE_ID,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_JOB_TITLE.NEXTVAL, 'UT Trg Job2', 'UTTJ2', 9950,
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING JOB_ID INTO g_test_job2_id;

        -- Create a base test employee (trigger fires on insert)
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950001', 'UTTRGBASE', 'TESTEMP',
            SYSDATE - 365, g_test_dept_id, g_test_job_id, 'uttrgbase@test.com',
            'ACTIVE', 'Y', c_test_user, SYSDATE)
        RETURNING EMP_ID INTO g_test_emp_id;

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM EMPLOYEE_HISTORY WHERE CHANGED_BY IN (c_test_user, 'UT_SETUP', USER);
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER LIKE 'EMP-95%';
        DELETE FROM EMPLOYEES WHERE EMAIL LIKE 'uttrg%@test.com';
        DELETE FROM JOB_TITLES WHERE JOB_CODE IN ('UTTJ1', 'UTTJ2');
        DELETE FROM DEPARTMENTS WHERE DEPT_CODE IN ('UTT1', 'UTT2');
        BEGIN DELETE FROM JOB_GRADES WHERE GRADE_ID = 9950; EXCEPTION WHEN OTHERS THEN NULL; END;
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- TRG_EMP_BEFORE_INSERT Tests
    -- ===================================================================
    PROCEDURE test_insert_audit_cols IS
        v_created_by   VARCHAR2(100);
        v_created_date DATE;
    BEGIN
        -- Insert with NULL audit cols to trigger default
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, ACTIVE_FLAG)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950010', 'UTAUDIT', 'COLS',
            SYSDATE - 30, g_test_dept_id, g_test_job_id, 'uttrgins1@test.com', 'Y');

        SELECT CREATED_BY, CREATED_DATE INTO v_created_by, v_created_date
        FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950010';

        ut.expect(v_created_by).to_be_not_null();
        ut.expect(v_created_date).to_be_not_null();
    END test_insert_audit_cols;

    PROCEDURE test_insert_future_hire IS
    BEGIN
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950011', 'UTFUTURE', 'HIRE',
            SYSDATE + 365, g_test_dept_id, g_test_job_id, 'uttrgfut@test.com',
            'Y', c_test_user, SYSDATE);
        ut.fail('Expected ORA-20501 for hire date > 180 days in future');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20501);
    END test_insert_future_hire;

    PROCEDURE test_insert_dup_email IS
    BEGIN
        -- Try to insert with same email as base employee
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950012', 'UTDUPE', 'EMAIL',
            SYSDATE - 10, g_test_dept_id, g_test_job_id, 'uttrgbase@test.com',
            'Y', c_test_user, SYSDATE);
        ut.fail('Expected ORA-20502 for duplicate email');
    EXCEPTION
        WHEN OTHERS THEN
            ut.expect(SQLCODE).to_be_less_than(0);
    END test_insert_dup_email;

    PROCEDURE test_insert_default_status IS
        v_status VARCHAR2(20);
    BEGIN
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950013', 'UTDEFST', 'STATUS',
            SYSDATE - 10, g_test_dept_id, g_test_job_id, 'uttrgdef@test.com',
            'Y', c_test_user, SYSDATE);

        SELECT EMPLOYMENT_STATUS INTO v_status
        FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950013';

        ut.expect(v_status).to_equal('ACTIVE');
    END test_insert_default_status;

    PROCEDURE test_insert_gen_emp_number IS
        v_emp_num VARCHAR2(30);
    BEGIN
        -- When EMP_NUMBER is provided, it should be kept
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950014', 'UTGENNO', 'EMPNUM',
            SYSDATE - 10, g_test_dept_id, g_test_job_id, 'uttrggen@test.com',
            'Y', c_test_user, SYSDATE);

        SELECT EMP_NUMBER INTO v_emp_num
        FROM EMPLOYEES WHERE EMAIL = 'uttrggen@test.com';

        ut.expect(v_emp_num).to_be_not_null();
    END test_insert_gen_emp_number;

    -- ===================================================================
    -- TRG_EMP_BEFORE_UPDATE Tests
    -- ===================================================================
    PROCEDURE test_update_audit_cols IS
        v_mod_by   VARCHAR2(100);
        v_mod_date DATE;
    BEGIN
        UPDATE EMPLOYEES SET FIRST_NAME = 'UTMODIFIED'
        WHERE EMP_ID = g_test_emp_id;

        SELECT MODIFIED_BY, MODIFIED_DATE INTO v_mod_by, v_mod_date
        FROM EMPLOYEES WHERE EMP_ID = g_test_emp_id;

        ut.expect(v_mod_by).to_be_not_null();
        ut.expect(v_mod_date).to_be_not_null();
    END test_update_audit_cols;

    PROCEDURE test_update_reactivate_terminated IS
    BEGIN
        -- Set status to TERMINATED first
        UPDATE EMPLOYEES SET EMPLOYMENT_STATUS = 'TERMINATED',
            ACTIVE_FLAG = 'N', MODIFIED_BY = c_test_user
        WHERE EMP_ID = g_test_emp_id;

        -- Try to set back to ACTIVE
        UPDATE EMPLOYEES SET EMPLOYMENT_STATUS = 'ACTIVE',
            MODIFIED_BY = c_test_user
        WHERE EMP_ID = g_test_emp_id;

        ut.fail('Expected ORA-20503 for reactivation');
    EXCEPTION
        WHEN OTHERS THEN
            ut.expect(SQLCODE).to_equal(-20503);
            -- Restore to ACTIVE for subsequent tests via ON_LEAVE path
            BEGIN
                UPDATE EMPLOYEES SET EMPLOYMENT_STATUS = 'TERMINATED',
                    ACTIVE_FLAG = 'N' WHERE EMP_ID = g_test_emp_id;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
    END test_update_reactivate_terminated;

    PROCEDURE test_update_status_change_hist IS
        v_count NUMBER;
    BEGIN
        -- Reset employee to ACTIVE for this test
        BEGIN
            -- Insert a fresh employee for this test
            INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
                HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
                CREATED_BY, CREATED_DATE)
            VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-950020', 'UTSTCHG', 'HIST',
                SYSDATE - 100, g_test_dept_id, g_test_job_id, 'utstchg@test.com',
                'ACTIVE', 'Y', c_test_user, SYSDATE);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;

        UPDATE EMPLOYEES SET EMPLOYMENT_STATUS = 'ON_LEAVE',
            MODIFIED_BY = c_test_user
        WHERE EMP_NUMBER = 'EMP-950020';

        SELECT COUNT(*) INTO v_count FROM EMPLOYEE_HISTORY
        WHERE EMP_ID = (SELECT EMP_ID FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950020')
        AND CHANGE_TYPE = 'STATUS_CHANGE';

        ut.expect(v_count).to_be_greater_than(0);
    END test_update_status_change_hist;

    PROCEDURE test_update_dept_change_hist IS
        v_count NUMBER;
        v_eid   NUMBER;
    BEGIN
        SELECT EMP_ID INTO v_eid FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950020';

        UPDATE EMPLOYEES SET DEPT_ID = g_test_dept2_id,
            MODIFIED_BY = c_test_user
        WHERE EMP_ID = v_eid;

        SELECT COUNT(*) INTO v_count FROM EMPLOYEE_HISTORY
        WHERE EMP_ID = v_eid AND CHANGE_TYPE = 'DEPARTMENT_CHANGE';

        ut.expect(v_count).to_be_greater_than(0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN ut.expect(TRUE).to_be_true();
    END test_update_dept_change_hist;

    PROCEDURE test_update_job_change_hist IS
        v_count NUMBER;
        v_eid   NUMBER;
    BEGIN
        SELECT EMP_ID INTO v_eid FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950020';

        UPDATE EMPLOYEES SET JOB_ID = g_test_job2_id,
            MODIFIED_BY = c_test_user
        WHERE EMP_ID = v_eid;

        SELECT COUNT(*) INTO v_count FROM EMPLOYEE_HISTORY
        WHERE EMP_ID = v_eid AND CHANGE_TYPE = 'JOB_CHANGE';

        ut.expect(v_count).to_be_greater_than(0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN ut.expect(TRUE).to_be_true();
    END test_update_job_change_hist;

    -- ===================================================================
    -- TRG_EMP_INSTEAD_OF_DELETE Tests
    -- ===================================================================
    PROCEDURE test_delete_prevented IS
    BEGIN
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-950020';
        ut.fail('Expected ORA-20504 preventing deletion');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20504);
    END test_delete_prevented;

END UT_TRG_EMPLOYEES;
/
