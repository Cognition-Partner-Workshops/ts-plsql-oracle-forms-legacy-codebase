CREATE OR REPLACE PACKAGE BODY HRMS.PKG_INTEGRATION AS
-- ============================================================================
-- PKG_INTEGRATION - External System Integration Package Body
-- ============================================================================

    -- File output directories (mapped to Oracle directory objects)
    c_gl_output_dir       CONSTANT VARCHAR2(30) := 'GL_FEED_OUT';
    c_benefits_output_dir CONSTANT VARCHAR2(30) := 'BENEFITS_FEED_OUT';
    c_time_input_dir      CONSTANT VARCHAR2(30) := 'TIME_ATTENDANCE_IN';

    -- -----------------------------------------------------------------------
    -- generate_gl_journal
    -- Creates GL journal entries from payroll run and writes to flat file
    -- File format: pipe-delimited, consumed by Oracle Financials batch import
    -- -----------------------------------------------------------------------
    PROCEDURE generate_gl_journal(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
        v_file     UTL_FILE.FILE_TYPE;
        v_filename VARCHAR2(100);
        v_entries  NUMBER := 0;
    BEGIN
        v_filename := 'GL_JOURNAL_' || p_run_id || '_' ||
                       TO_CHAR(SYSDATE, 'YYYYMMDD') || '.dat';

        v_file := UTL_FILE.FOPEN(c_gl_output_dir, v_filename, 'W', 32767);

        -- Header record
        UTL_FILE.PUT_LINE(v_file,
            'H|HRMS_PAYROLL|' || TO_CHAR(SYSDATE, 'YYYY-MM-DD') || '|' || p_run_id);

        -- Generate debit/credit entries per department
        FOR rec IN (
            SELECT d.COST_CENTER,
                   pe.GL_ACCOUNT_CODE,
                   pe.ELEMENT_TYPE,
                   SUM(pd.AMOUNT) AS TOTAL_AMOUNT,
                   pp.PERIOD_NAME
            FROM PAYROLL_DETAILS pd
            JOIN PAYROLL_RUNS pr ON pd.RUN_ID = pr.RUN_ID
            JOIN PAY_PERIODS pp ON pr.PERIOD_ID = pp.PERIOD_ID
            JOIN EMPLOYEES e ON pd.EMP_ID = e.EMP_ID
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            JOIN PAY_ELEMENTS pe ON pd.ELEMENT_ID = pe.ELEMENT_ID
            WHERE pd.RUN_ID = p_run_id
            AND pd.STATUS != 'ERROR'
            AND pe.GL_ACCOUNT_CODE IS NOT NULL
            GROUP BY d.COST_CENTER, pe.GL_ACCOUNT_CODE,
                     pe.ELEMENT_TYPE, pp.PERIOD_NAME
        ) LOOP
            -- Earnings are debits to expense accounts
            -- Deductions/taxes are credits to liability accounts
            IF rec.ELEMENT_TYPE = 'EARNING' THEN
                UTL_FILE.PUT_LINE(v_file,
                    'D|' || rec.COST_CENTER || '|' || rec.GL_ACCOUNT_CODE || '|' ||
                    TO_CHAR(ABS(rec.TOTAL_AMOUNT), 'FM999999990.00') || '|0.00|' ||
                    'Payroll ' || rec.PERIOD_NAME || '|RUN-' || p_run_id);
            ELSE
                UTL_FILE.PUT_LINE(v_file,
                    'D|' || rec.COST_CENTER || '|' || rec.GL_ACCOUNT_CODE || '|0.00|' ||
                    TO_CHAR(ABS(rec.TOTAL_AMOUNT), 'FM999999990.00') || '|' ||
                    'Payroll ' || rec.PERIOD_NAME || '|RUN-' || p_run_id);
            END IF;

            v_entries := v_entries + 1;
        END LOOP;

        -- Trailer record
        UTL_FILE.PUT_LINE(v_file, 'T|' || v_entries);

        UTL_FILE.FCLOSE(v_file);

        PKG_COMMON.log_info('PKG_INTEGRATION', 'generate_gl_journal',
            'Generated ' || v_entries || ' GL entries: ' || v_filename, p_user);
    EXCEPTION
        WHEN OTHERS THEN
            IF UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;
            PKG_COMMON.log_error('PKG_INTEGRATION', 'generate_gl_journal', SQLERRM, p_user);
            RAISE;
    END generate_gl_journal;

    -- -----------------------------------------------------------------------
    -- export_benefits_feed
    -- ADP-format benefits enrollment file
    -- LEGACY: Fixed-width format, specific to ADP vendor
    -- -----------------------------------------------------------------------
    PROCEDURE export_benefits_feed(
        p_effective_date IN DATE DEFAULT SYSDATE,
        p_user           IN VARCHAR2 DEFAULT USER
    ) IS
        v_file     UTL_FILE.FILE_TYPE;
        v_filename VARCHAR2(100);
        v_records  NUMBER := 0;
    BEGIN
        v_filename := 'BENEFITS_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.txt';
        v_file := UTL_FILE.FOPEN(c_benefits_output_dir, v_filename, 'W', 32767);

        FOR rec IN (
            SELECT e.EMP_NUMBER,
                   e.FIRST_NAME, e.LAST_NAME,
                   e.DATE_OF_BIRTH,
                   e.HIRE_DATE,
                   e.EMPLOYMENT_STATUS,
                   e.MARITAL_STATUS,
                   e.GENDER,
                   d.FIRST_NAME AS DEP_FIRST_NAME,
                   d.LAST_NAME AS DEP_LAST_NAME,
                   d.RELATIONSHIP,
                   d.DATE_OF_BIRTH AS DEP_DOB
            FROM EMPLOYEES e
            LEFT JOIN EMPLOYEE_DEPENDENTS d ON e.EMP_ID = d.EMP_ID AND d.ACTIVE_FLAG = 'Y'
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            ORDER BY e.EMP_NUMBER, d.DEPENDENT_ID
        ) LOOP
            -- Fixed-width format: EmpNum(10) | FName(30) | LName(30) | DOB(10) | ...
            UTL_FILE.PUT_LINE(v_file,
                RPAD(NVL(rec.EMP_NUMBER, ' '), 10) ||
                RPAD(NVL(rec.FIRST_NAME, ' '), 30) ||
                RPAD(NVL(rec.LAST_NAME, ' '), 30) ||
                RPAD(NVL(TO_CHAR(rec.DATE_OF_BIRTH, 'YYYY-MM-DD'), ' '), 10) ||
                RPAD(NVL(TO_CHAR(rec.HIRE_DATE, 'YYYY-MM-DD'), ' '), 10) ||
                RPAD(NVL(rec.EMPLOYMENT_STATUS, ' '), 12) ||
                RPAD(NVL(rec.MARITAL_STATUS, ' '), 10) ||
                RPAD(NVL(rec.GENDER, ' '), 1) ||
                RPAD(NVL(rec.DEP_FIRST_NAME, ' '), 30) ||
                RPAD(NVL(rec.DEP_LAST_NAME, ' '), 30) ||
                RPAD(NVL(rec.RELATIONSHIP, ' '), 20) ||
                RPAD(NVL(TO_CHAR(rec.DEP_DOB, 'YYYY-MM-DD'), ' '), 10)
            );
            v_records := v_records + 1;
        END LOOP;

        UTL_FILE.FCLOSE(v_file);

        PKG_COMMON.log_info('PKG_INTEGRATION', 'export_benefits_feed',
            'Exported ' || v_records || ' records: ' || v_filename, p_user);
    EXCEPTION
        WHEN OTHERS THEN
            IF UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;
            PKG_COMMON.log_error('PKG_INTEGRATION', 'export_benefits_feed', SQLERRM, p_user);
            RAISE;
    END export_benefits_feed;

    -- -----------------------------------------------------------------------
    -- import_time_attendance
    -- Reads time data from CSV file and updates payroll
    -- -----------------------------------------------------------------------
    PROCEDURE import_time_attendance(
        p_file_name IN VARCHAR2,
        p_user      IN VARCHAR2 DEFAULT USER
    ) IS
        v_file      UTL_FILE.FILE_TYPE;
        v_line      VARCHAR2(4000);
        v_imported  NUMBER := 0;
        v_errors    NUMBER := 0;
    BEGIN
        v_file := UTL_FILE.FOPEN(c_time_input_dir, p_file_name, 'R', 32767);

        LOOP
            BEGIN
                UTL_FILE.GET_LINE(v_file, v_line);

                IF v_line IS NOT NULL AND SUBSTR(v_line, 1, 1) != '#' THEN
                    -- Parse CSV: emp_number,date,hours_regular,hours_overtime
                    -- TODO: Implement actual parsing and database update
                    v_imported := v_imported + 1;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    EXIT;
                WHEN OTHERS THEN
                    v_errors := v_errors + 1;
                    PKG_COMMON.log_error('PKG_INTEGRATION', 'import_time_attendance',
                        'Line error: ' || SQLERRM, p_user);
            END;
        END LOOP;

        UTL_FILE.FCLOSE(v_file);

        PKG_COMMON.log_info('PKG_INTEGRATION', 'import_time_attendance',
            'Imported: ' || v_imported || ', Errors: ' || v_errors, p_user);
    EXCEPTION
        WHEN OTHERS THEN
            IF UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;
            PKG_COMMON.log_error('PKG_INTEGRATION', 'import_time_attendance', SQLERRM, p_user);
            RAISE;
    END import_time_attendance;

    PROCEDURE sync_org_structure(
        p_user IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        -- Placeholder for org structure sync with external directory (LDAP/AD)
        PKG_COMMON.log_info('PKG_INTEGRATION', 'sync_org_structure',
            'Org structure sync completed', p_user);
    END sync_org_structure;

    FUNCTION get_integration_status(
        p_integration_name IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN PKG_COMMON.get_param('INTEGRATION', p_integration_name || '_STATUS');
    END get_integration_status;

END PKG_INTEGRATION;
/
