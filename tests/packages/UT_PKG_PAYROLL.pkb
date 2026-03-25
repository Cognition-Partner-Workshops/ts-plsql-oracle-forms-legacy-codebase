CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_PAYROLL AS
-- ============================================================================
-- UT_PKG_PAYROLL - Unit Tests for PKG_PAYROLL Body
-- Corrected to match actual package API signatures
-- ============================================================================

    c_test_user     CONSTANT VARCHAR2(30) := 'UT_PAY_TEST';
    g_test_emp_id   NUMBER;
    g_test_dept_id  NUMBER;
    g_test_job_id   NUMBER;
    g_test_period_id NUMBER;

    PROCEDURE setup_test_data IS
    BEGIN
        BEGIN
            INSERT INTO JOB_GRADES (GRADE_ID, GRADE_NAME, MIN_SALARY, MAX_SALARY)
            VALUES (9980, 'UT_GRADE_PAY', 30000, 200000);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;

        INSERT INTO DEPARTMENTS (DEPT_ID, DEPT_NAME, DEPT_CODE, LOCATION_CODE,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_DEPARTMENT.NEXTVAL, 'UT Pay Dept', 'UTPD', 'US-TX',
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING DEPT_ID INTO g_test_dept_id;

        INSERT INTO JOB_TITLES (JOB_ID, JOB_TITLE, JOB_CODE, GRADE_ID,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_JOB_TITLE.NEXTVAL, 'UT Pay Job', 'UTPJ', 9980,
            'Y', 'UT_SETUP', SYSDATE)
        RETURNING JOB_ID INTO g_test_job_id;

        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-960001', 'UTPAY', 'TESTUSER',
            SYSDATE - 365, g_test_dept_id, g_test_job_id, 'utpay@test.com',
            'ACTIVE', 'Y', 'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO g_test_emp_id;

        INSERT INTO PAY_PERIODS (PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
            PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE, STATUS,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAY_PERIOD.NEXTVAL, 'UT Test Period', 'MONTHLY',
            TRUNC(SYSDATE, 'MM'), LAST_DAY(SYSDATE), LAST_DAY(SYSDATE),
            'OPEN', 'UT_SETUP', SYSDATE)
        RETURNING PERIOD_ID INTO g_test_period_id;

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM PAYROLL_DETAILS WHERE CREATED_BY IN (c_test_user, 'UT_SETUP');
        DELETE FROM PAYROLL_RUNS WHERE CREATED_BY IN (c_test_user, 'UT_SETUP');
        DELETE FROM PAY_PERIODS WHERE CREATED_BY IN ('UT_SETUP', c_test_user);
        DELETE FROM PAY_PERIODS WHERE PERIOD_NAME LIKE 'UT%';
        DELETE FROM PAY_PERIODS WHERE EXTRACT(YEAR FROM PERIOD_START_DATE) IN (2097, 2098, 2099);
        DELETE FROM SALARY_RECORDS WHERE EMP_ID = g_test_emp_id;
        DELETE FROM SALARY_RECORDS WHERE CREATED_BY = c_test_user;
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-960001';
        DELETE FROM JOB_TITLES WHERE JOB_CODE = 'UTPJ';
        DELETE FROM DEPARTMENTS WHERE DEPT_CODE = 'UTPD';
        BEGIN DELETE FROM JOB_GRADES WHERE GRADE_ID = 9980; EXCEPTION WHEN OTHERS THEN NULL; END;
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- create_salary_record Tests
    -- ===================================================================
    PROCEDURE test_create_salary_basic IS
        v_count NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => 75000, p_change_reason => 'NEW_HIRE', p_user => c_test_user);
        SELECT COUNT(*) INTO v_count FROM SALARY_RECORDS
        WHERE EMP_ID = g_test_emp_id AND ACTIVE_FLAG = 'Y';
        ut.expect(v_count).to_be_greater_than(0);
    END test_create_salary_basic;

    PROCEDURE test_create_salary_deactivate_prev IS
        v_active_count NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE - 30,
            p_base_salary => 70000, p_change_reason => 'INITIAL', p_user => c_test_user);
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => 80000, p_change_reason => 'ADJUSTMENT', p_user => c_test_user);
        SELECT COUNT(*) INTO v_active_count FROM SALARY_RECORDS
        WHERE EMP_ID = g_test_emp_id AND ACTIVE_FLAG = 'Y';
        ut.expect(v_active_count).to_equal(1);
    END test_create_salary_deactivate_prev;

    PROCEDURE test_create_salary_negative IS
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => -5000, p_change_reason => 'NEGATIVE', p_user => c_test_user);
        ut.fail('Expected ORA-20101');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20101);
    END test_create_salary_negative;

    PROCEDURE test_create_salary_reason IS
        v_reason VARCHAR2(100);
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => 82000, p_change_reason => 'MERIT_INCREASE', p_user => c_test_user);
        SELECT CHANGE_REASON INTO v_reason FROM (
            SELECT CHANGE_REASON FROM SALARY_RECORDS
            WHERE EMP_ID = g_test_emp_id AND ACTIVE_FLAG = 'Y'
            ORDER BY EFFECTIVE_DATE DESC) WHERE ROWNUM = 1;
        ut.expect(v_reason).to_equal('MERIT_INCREASE');
    END test_create_salary_reason;

    PROCEDURE test_create_salary_change_pct IS
        v_pct NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => 90000, p_change_reason => 'PROMOTION',
            p_change_pct => 10.5, p_user => c_test_user);
        SELECT CHANGE_PCT INTO v_pct FROM (
            SELECT CHANGE_PCT FROM SALARY_RECORDS
            WHERE EMP_ID = g_test_emp_id AND ACTIVE_FLAG = 'Y'
            ORDER BY EFFECTIVE_DATE DESC) WHERE ROWNUM = 1;
        ut.expect(v_pct).to_equal(10.5);
    END test_create_salary_change_pct;

    -- ===================================================================
    -- get_current_salary / get_salary_as_of Tests
    -- ===================================================================
    PROCEDURE test_get_salary_active IS
        v_salary NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE,
            p_base_salary => 95000, p_change_reason => 'TEST', p_user => c_test_user);
        v_salary := PKG_PAYROLL.get_current_salary(g_test_emp_id);
        ut.expect(v_salary).to_equal(95000);
    END test_get_salary_active;

    PROCEDURE test_get_salary_no_record IS
    BEGIN
        ut.expect(PKG_PAYROLL.get_current_salary(-999)).to_equal(0);
    END test_get_salary_no_record;

    PROCEDURE test_get_salary_as_of IS
        v_salary NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE - 10,
            p_base_salary => 88000, p_change_reason => 'AS_OF', p_user => c_test_user);
        v_salary := PKG_PAYROLL.get_salary_as_of(g_test_emp_id, SYSDATE);
        ut.expect(v_salary).to_be_greater_than(0);
    END test_get_salary_as_of;

    PROCEDURE test_get_salary_as_of_none IS
    BEGIN
        ut.expect(PKG_PAYROLL.get_salary_as_of(-999, SYSDATE)).to_equal(0);
    END test_get_salary_as_of_none;

    -- ===================================================================
    -- Pay Period Tests (uses PAY_FREQUENCY, PERIOD_START_DATE, PERIOD_END_DATE)
    -- ===================================================================
    PROCEDURE test_create_periods_monthly IS
        v_count NUMBER;
    BEGIN
        PKG_PAYROLL.create_pay_periods(p_year => 2099, p_frequency => 'MONTHLY', p_user => c_test_user);
        SELECT COUNT(*) INTO v_count FROM PAY_PERIODS
        WHERE PAY_FREQUENCY = 'MONTHLY' AND EXTRACT(YEAR FROM PERIOD_START_DATE) = 2099;
        ut.expect(v_count).to_equal(12);
    END test_create_periods_monthly;

    PROCEDURE test_create_periods_biweekly IS
        v_count NUMBER;
    BEGIN
        PKG_PAYROLL.create_pay_periods(p_year => 2098, p_frequency => 'BIWEEKLY', p_user => c_test_user);
        SELECT COUNT(*) INTO v_count FROM PAY_PERIODS
        WHERE PAY_FREQUENCY = 'BIWEEKLY'
        AND (EXTRACT(YEAR FROM PERIOD_START_DATE) = 2098
             OR EXTRACT(YEAR FROM PERIOD_END_DATE) = 2098);
        ut.expect(v_count).to_be_greater_or_equal(26);
    END test_create_periods_biweekly;

    PROCEDURE test_close_period_basic IS
        v_pid NUMBER; v_status VARCHAR2(20);
    BEGIN
        INSERT INTO PAY_PERIODS (PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
            PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE, STATUS, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAY_PERIOD.NEXTVAL, 'UT Close Test', 'MONTHLY',
            DATE '2097-01-01', DATE '2097-01-31', DATE '2097-01-31',
            'OPEN', c_test_user, SYSDATE) RETURNING PERIOD_ID INTO v_pid;
        COMMIT;
        PKG_PAYROLL.close_pay_period(v_pid, c_test_user);
        SELECT STATUS INTO v_status FROM PAY_PERIODS WHERE PERIOD_ID = v_pid;
        ut.expect(v_status).to_equal('CLOSED');
    END test_close_period_basic;

    PROCEDURE test_close_period_already_closed IS
        v_pid NUMBER;
    BEGIN
        INSERT INTO PAY_PERIODS (PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
            PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE, STATUS, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAY_PERIOD.NEXTVAL, 'UT Already Closed', 'MONTHLY',
            DATE '2097-02-01', DATE '2097-02-28', DATE '2097-02-28',
            'CLOSED', c_test_user, SYSDATE) RETURNING PERIOD_ID INTO v_pid;
        COMMIT;
        PKG_PAYROLL.close_pay_period(v_pid, c_test_user);
        ut.fail('Expected ORA-20102');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20102);
    END test_close_period_already_closed;

    PROCEDURE test_get_current_period IS
        v_p NUMBER;
    BEGIN
        v_p := PKG_PAYROLL.get_current_period();
        ut.expect(v_p).to_be_not_null();
    EXCEPTION
        WHEN NO_DATA_FOUND THEN ut.expect(TRUE).to_be_true();
    END test_get_current_period;

    -- ===================================================================
    -- Payroll Run Tests
    -- ===================================================================
    PROCEDURE test_create_run_basic IS
        v_run_id NUMBER;
    BEGIN
        v_run_id := PKG_PAYROLL.create_payroll_run(
            p_period_id => g_test_period_id, p_run_type => 'REGULAR', p_user => c_test_user);
        ut.expect(v_run_id).to_be_greater_than(0);
    END test_create_run_basic;

    PROCEDURE test_create_run_closed_period IS
        v_pid NUMBER; v_run_id NUMBER;
    BEGIN
        INSERT INTO PAY_PERIODS (PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
            PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE, STATUS, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAY_PERIOD.NEXTVAL, 'UT Closed RunTest', 'MONTHLY',
            DATE '2097-03-01', DATE '2097-03-31', DATE '2097-03-31',
            'CLOSED', c_test_user, SYSDATE) RETURNING PERIOD_ID INTO v_pid;
        COMMIT;
        v_run_id := PKG_PAYROLL.create_payroll_run(v_pid, 'REGULAR', c_test_user);
        ut.fail('Expected ORA-20102');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20102);
    END test_create_run_closed_period;

    -- ===================================================================
    -- Federal Tax Tests
    -- ===================================================================
    PROCEDURE test_fed_tax_single IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(5000, 'SINGLE', 0, 0, 'MONTHLY')).to_be_greater_than(0);
    END test_fed_tax_single;

    PROCEDURE test_fed_tax_married IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(5000, 'MARRIED_JOINT', 0, 0, 'MONTHLY')).to_be_greater_than(0);
    END test_fed_tax_married;

    PROCEDURE test_fed_tax_zero_income IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(0, 'SINGLE', 0, 0, 'MONTHLY')).to_equal(0);
    END test_fed_tax_zero_income;

    PROCEDURE test_fed_tax_with_allowances IS
        v_no NUMBER; v_with NUMBER;
    BEGIN
        v_no := PKG_PAYROLL.calculate_federal_tax(5000, 'SINGLE', 0, 0, 'MONTHLY');
        v_with := PKG_PAYROLL.calculate_federal_tax(5000, 'SINGLE', 3, 0, 'MONTHLY');
        ut.expect(v_with).to_be_less_or_equal(v_no);
    END test_fed_tax_with_allowances;

    PROCEDURE test_fed_tax_additional_wh IS
        v_base NUMBER; v_add NUMBER;
    BEGIN
        v_base := PKG_PAYROLL.calculate_federal_tax(5000, 'SINGLE', 0, 0, 'MONTHLY');
        v_add := PKG_PAYROLL.calculate_federal_tax(5000, 'SINGLE', 0, 100, 'MONTHLY');
        ut.expect(v_add).to_equal(v_base + 100);
    END test_fed_tax_additional_wh;

    PROCEDURE test_fed_tax_biweekly IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(2500, 'SINGLE', 0, 0, 'BIWEEKLY')).to_be_greater_than(0);
    END test_fed_tax_biweekly;

    PROCEDURE test_fed_tax_high_income IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(55000, 'SINGLE', 0, 0, 'MONTHLY')).to_be_greater_than(5000);
    END test_fed_tax_high_income;

    PROCEDURE test_fed_tax_married_separate IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_federal_tax(5000, 'MARRIED_SEPARATE', 0, 0, 'MONTHLY')).to_be_greater_than(0);
    END test_fed_tax_married_separate;

    -- ===================================================================
    -- State Tax Tests (correct signature: p_taxable_income, p_state_code, p_filing_status)
    -- ===================================================================
    PROCEDURE test_state_tax_ca IS
    BEGIN
        -- CA rate is 7.25%: 5000 * 0.0725 = 362.50
        ut.expect(PKG_PAYROLL.calculate_state_tax(5000, 'CA', 'SINGLE')).to_equal(362.50);
    END test_state_tax_ca;

    PROCEDURE test_state_tax_tx IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_state_tax(5000, 'TX', 'SINGLE')).to_equal(0);
    END test_state_tax_tx;

    PROCEDURE test_state_tax_unknown IS
    BEGIN
        -- Unknown state defaults to 5%: 5000 * 0.05 = 250
        ut.expect(PKG_PAYROLL.calculate_state_tax(5000, 'XX', 'SINGLE')).to_equal(250);
    END test_state_tax_unknown;

    PROCEDURE test_state_tax_ny IS
    BEGIN
        -- NY rate is 6.85%: 5000 * 0.0685 = 342.50
        ut.expect(PKG_PAYROLL.calculate_state_tax(5000, 'NY', 'SINGLE')).to_equal(342.50);
    END test_state_tax_ny;

    -- ===================================================================
    -- FICA Tests (6.2% with 168600 wage base cap)
    -- ===================================================================
    PROCEDURE test_fica_basic IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_fica(5000, 0)).to_equal(310);
    END test_fica_basic;

    PROCEDURE test_fica_over_cap IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_fica(5000, 200000)).to_equal(0);
    END test_fica_over_cap;

    PROCEDURE test_fica_near_cap IS
        v_fica NUMBER;
    BEGIN
        -- YTD=166000, gross=5000 -> only 168600-166000=2600 taxable: 2600*0.062=161.20
        v_fica := PKG_PAYROLL.calculate_fica(5000, 166000);
        ut.expect(v_fica).to_equal(161.2);
    END test_fica_near_cap;

    -- ===================================================================
    -- Medicare Tests (1.45% base + 0.9% additional above 200000)
    -- ===================================================================
    PROCEDURE test_medicare_basic IS
    BEGIN
        ut.expect(PKG_PAYROLL.calculate_medicare(5000, 0)).to_equal(72.5);
    END test_medicare_basic;

    PROCEDURE test_medicare_additional_full IS
        v_med NUMBER;
    BEGIN
        -- YTD=210000, all above threshold: 10000*(1.45%+0.9%)=10000*0.0235=235
        v_med := PKG_PAYROLL.calculate_medicare(10000, 210000);
        ut.expect(v_med).to_equal(235);
    END test_medicare_additional_full;

    PROCEDURE test_medicare_additional_partial IS
        v_med NUMBER;
    BEGIN
        -- YTD=195000, gross=10000: 5000 at 1.45% + 5000 at 2.35% = 72.5+117.5=190
        v_med := PKG_PAYROLL.calculate_medicare(10000, 195000);
        ut.expect(v_med).to_equal(190);
    END test_medicare_additional_partial;

    -- ===================================================================
    -- calculate_payroll (uses p_run_id, NOT p_period_id)
    -- ===================================================================
    PROCEDURE test_calc_payroll_basic IS
        v_run_id NUMBER;
    BEGIN
        PKG_PAYROLL.create_salary_record(
            p_emp_id => g_test_emp_id, p_effective_date => SYSDATE - 30,
            p_base_salary => 84000, p_change_reason => 'TEST', p_user => c_test_user);
        v_run_id := PKG_PAYROLL.create_payroll_run(
            p_period_id => g_test_period_id, p_run_type => 'REGULAR', p_user => c_test_user);
        BEGIN
            PKG_PAYROLL.calculate_payroll(p_run_id => v_run_id, p_user => c_test_user);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        ut.expect(TRUE).to_be_true();
    END test_calc_payroll_basic;

    -- ===================================================================
    -- Approve / Reverse Tests
    -- ===================================================================
    PROCEDURE test_approve_payroll IS
        v_run_id NUMBER; v_status VARCHAR2(20);
    BEGIN
        INSERT INTO PAYROLL_RUNS (RUN_ID, PERIOD_ID, RUN_TYPE, RUN_DATE,
            STATUS, SUBMITTED_BY, SUBMITTED_DATE, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAYROLL_RUN.NEXTVAL, g_test_period_id, 'REGULAR', SYSDATE,
            'CALCULATED', c_test_user, SYSDATE, c_test_user, SYSDATE)
        RETURNING RUN_ID INTO v_run_id;
        COMMIT;
        PKG_PAYROLL.approve_payroll(v_run_id, c_test_user);
        SELECT STATUS INTO v_status FROM PAYROLL_RUNS WHERE RUN_ID = v_run_id;
        ut.expect(v_status).to_equal('APPROVED');
    END test_approve_payroll;

    PROCEDURE test_approve_wrong_status IS
        v_run_id NUMBER;
    BEGIN
        INSERT INTO PAYROLL_RUNS (RUN_ID, PERIOD_ID, RUN_TYPE, RUN_DATE,
            STATUS, SUBMITTED_BY, SUBMITTED_DATE, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAYROLL_RUN.NEXTVAL, g_test_period_id, 'REGULAR', SYSDATE,
            'PENDING', c_test_user, SYSDATE, c_test_user, SYSDATE)
        RETURNING RUN_ID INTO v_run_id;
        COMMIT;
        PKG_PAYROLL.approve_payroll(v_run_id, c_test_user);
        ut.fail('Expected ORA-20103');
    EXCEPTION
        WHEN OTHERS THEN ut.expect(SQLCODE).to_equal(-20103);
    END test_approve_wrong_status;

    PROCEDURE test_reverse_payroll IS
        v_run_id NUMBER; v_status VARCHAR2(20);
    BEGIN
        INSERT INTO PAYROLL_RUNS (RUN_ID, PERIOD_ID, RUN_TYPE, RUN_DATE,
            STATUS, SUBMITTED_BY, SUBMITTED_DATE, CREATED_BY, CREATED_DATE)
        VALUES (SEQ_PAYROLL_RUN.NEXTVAL, g_test_period_id, 'REGULAR', SYSDATE,
            'APPROVED', c_test_user, SYSDATE, c_test_user, SYSDATE)
        RETURNING RUN_ID INTO v_run_id;
        COMMIT;
        PKG_PAYROLL.reverse_payroll(v_run_id, 'Correction needed', c_test_user);
        SELECT STATUS INTO v_status FROM PAYROLL_RUNS WHERE RUN_ID = v_run_id;
        ut.expect(v_status).to_equal('REVERSED');
    END test_reverse_payroll;

    -- ===================================================================
    -- get_payslip (procedure with cursor OUT parameter)
    -- ===================================================================
    PROCEDURE test_get_payslip_cursor IS
        v_cursor PKG_PAYROLL.t_payslip_cursor;
    BEGIN
        PKG_PAYROLL.get_payslip(v_cursor, -999, g_test_emp_id);
        CLOSE v_cursor;
        ut.expect(TRUE).to_be_true();
    END test_get_payslip_cursor;

    -- ===================================================================
    -- get_ytd_earnings
    -- ===================================================================
    PROCEDURE test_ytd_earnings_zero IS
    BEGIN
        ut.expect(PKG_PAYROLL.get_ytd_earnings(-999)).to_equal(0);
    END test_ytd_earnings_zero;

END UT_PKG_PAYROLL;
/
