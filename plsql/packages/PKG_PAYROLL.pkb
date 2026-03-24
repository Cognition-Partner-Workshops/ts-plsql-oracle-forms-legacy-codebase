CREATE OR REPLACE PACKAGE BODY HRMS.PKG_PAYROLL AS
-- ============================================================================
-- PKG_PAYROLL - Payroll Processing Package Body
-- ============================================================================

    -- Constants
    c_ss_wage_base_2024   CONSTANT NUMBER := 168600;   -- Social Security wage base
    c_ss_rate             CONSTANT NUMBER := 0.062;     -- 6.2% employee share
    c_medicare_rate       CONSTANT NUMBER := 0.0145;    -- 1.45% employee share
    c_medicare_addl_rate  CONSTANT NUMBER := 0.009;     -- Additional Medicare tax
    c_medicare_addl_threshold CONSTANT NUMBER := 200000; -- Threshold for additional Medicare
    c_standard_deduction_single CONSTANT NUMBER := 14600;
    c_standard_deduction_married CONSTANT NUMBER := 29200;
    c_allowance_amount    CONSTANT NUMBER := 4300;      -- Per-allowance reduction

    -- -----------------------------------------------------------------------
    -- create_salary_record
    -- -----------------------------------------------------------------------
    PROCEDURE create_salary_record(
        p_emp_id         IN NUMBER,
        p_effective_date IN DATE,
        p_base_salary    IN NUMBER,
        p_change_reason  IN VARCHAR2 DEFAULT NULL,
        p_change_pct     IN NUMBER DEFAULT NULL,
        p_currency_code  IN VARCHAR2 DEFAULT 'USD',
        p_pay_frequency  IN VARCHAR2 DEFAULT 'MONTHLY',
        p_user           IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        IF p_base_salary <= 0 THEN
            RAISE_APPLICATION_ERROR(-20101, 'Salary must be positive: ' || p_base_salary);
        END IF;

        -- End-date current active salary
        UPDATE SALARY_RECORDS
        SET END_DATE = p_effective_date - 1,
            ACTIVE_FLAG = 'N',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y'
        AND EFFECTIVE_DATE < p_effective_date;

        -- Insert new salary record
        INSERT INTO SALARY_RECORDS (
            SALARY_ID, EMP_ID, EFFECTIVE_DATE, BASE_SALARY,
            CURRENCY_CODE, PAY_FREQUENCY, SALARY_BASIS,
            CHANGE_REASON, CHANGE_PCT, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SALARY.NEXTVAL, p_emp_id, p_effective_date, p_base_salary,
            p_currency_code, p_pay_frequency, 'ANNUAL',
            p_change_reason, p_change_pct, 'Y',
            p_user, SYSDATE
        );

        PKG_AUDIT.log_action('SALARY_RECORDS', SEQ_SALARY.CURRVAL, 'INSERT', p_user);
    END create_salary_record;

    -- -----------------------------------------------------------------------
    -- get_current_salary
    -- -----------------------------------------------------------------------
    FUNCTION get_current_salary(
        p_emp_id IN NUMBER
    ) RETURN NUMBER IS
        v_salary NUMBER;
    BEGIN
        SELECT BASE_SALARY INTO v_salary
        FROM SALARY_RECORDS
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y'
        AND EFFECTIVE_DATE <= SYSDATE
        AND (END_DATE IS NULL OR END_DATE > SYSDATE)
        ORDER BY EFFECTIVE_DATE DESC
        FETCH FIRST 1 ROW ONLY;

        RETURN v_salary;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END get_current_salary;

    -- -----------------------------------------------------------------------
    -- get_salary_as_of
    -- -----------------------------------------------------------------------
    FUNCTION get_salary_as_of(
        p_emp_id   IN NUMBER,
        p_as_of    IN DATE
    ) RETURN NUMBER IS
        v_salary NUMBER;
    BEGIN
        SELECT BASE_SALARY INTO v_salary
        FROM SALARY_RECORDS
        WHERE EMP_ID = p_emp_id
        AND EFFECTIVE_DATE <= p_as_of
        AND (END_DATE IS NULL OR END_DATE >= p_as_of)
        ORDER BY EFFECTIVE_DATE DESC
        FETCH FIRST 1 ROW ONLY;

        RETURN v_salary;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END get_salary_as_of;

    -- -----------------------------------------------------------------------
    -- create_pay_periods
    -- Generates pay periods for a full year
    -- -----------------------------------------------------------------------
    PROCEDURE create_pay_periods(
        p_year          IN NUMBER,
        p_frequency     IN VARCHAR2 DEFAULT 'MONTHLY',
        p_user          IN VARCHAR2 DEFAULT USER
    ) IS
        v_start_date DATE;
        v_end_date   DATE;
        v_pay_date   DATE;
        v_period_num NUMBER := 0;
    BEGIN
        IF p_frequency = 'MONTHLY' THEN
            FOR i IN 1..12 LOOP
                v_start_date := TO_DATE(p_year || '-' || LPAD(i, 2, '0') || '-01', 'YYYY-MM-DD');
                v_end_date := LAST_DAY(v_start_date);
                v_pay_date := v_end_date;

                -- If pay date falls on weekend, move to Friday
                IF TO_CHAR(v_pay_date, 'DY') = 'SAT' THEN
                    v_pay_date := v_pay_date - 1;
                ELSIF TO_CHAR(v_pay_date, 'DY') = 'SUN' THEN
                    v_pay_date := v_pay_date - 2;
                END IF;

                v_period_num := v_period_num + 1;

                INSERT INTO PAY_PERIODS (
                    PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
                    PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE,
                    STATUS, CREATED_BY, CREATED_DATE
                ) VALUES (
                    SEQ_PAY_PERIOD.NEXTVAL,
                    p_year || '-' || LPAD(i, 2, '0') || ' (' || TO_CHAR(v_start_date, 'Mon') || ')',
                    p_frequency,
                    v_start_date, v_end_date, v_pay_date,
                    'OPEN', p_user, SYSDATE
                );
            END LOOP;

        ELSIF p_frequency = 'BIWEEKLY' THEN
            v_start_date := TO_DATE(p_year || '-01-01', 'YYYY-MM-DD');
            -- Find first Friday
            WHILE TO_CHAR(v_start_date, 'DY') != 'FRI' LOOP
                v_start_date := v_start_date + 1;
            END LOOP;
            v_start_date := v_start_date - 13; -- Back up to start of pay period

            WHILE EXTRACT(YEAR FROM v_start_date) <= p_year LOOP
                v_end_date := v_start_date + 13;
                v_pay_date := v_end_date + 5; -- Pay 5 days after period end
                v_period_num := v_period_num + 1;

                IF EXTRACT(YEAR FROM v_start_date) = p_year OR
                   EXTRACT(YEAR FROM v_end_date) = p_year THEN

                    INSERT INTO PAY_PERIODS (
                        PERIOD_ID, PERIOD_NAME, PAY_FREQUENCY,
                        PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE,
                        STATUS, CREATED_BY, CREATED_DATE
                    ) VALUES (
                        SEQ_PAY_PERIOD.NEXTVAL,
                        p_year || '-BW-' || LPAD(v_period_num, 2, '0'),
                        p_frequency,
                        v_start_date, v_end_date, v_pay_date,
                        'OPEN', p_user, SYSDATE
                    );
                END IF;

                v_start_date := v_end_date + 1;
            END LOOP;
        END IF;

        COMMIT;
    END create_pay_periods;

    -- -----------------------------------------------------------------------
    -- close_pay_period
    -- -----------------------------------------------------------------------
    PROCEDURE close_pay_period(
        p_period_id IN NUMBER,
        p_user      IN VARCHAR2 DEFAULT USER
    ) IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT STATUS INTO v_status
        FROM PAY_PERIODS
        WHERE PERIOD_ID = p_period_id
        FOR UPDATE;

        IF v_status = 'CLOSED' THEN
            RAISE_APPLICATION_ERROR(-20102, 'Period already closed: ' || p_period_id);
        END IF;

        UPDATE PAY_PERIODS
        SET STATUS = 'CLOSED',
            CLOSED_BY = p_user,
            CLOSED_DATE = SYSDATE,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE PERIOD_ID = p_period_id;
    END close_pay_period;

    -- -----------------------------------------------------------------------
    -- get_current_period
    -- -----------------------------------------------------------------------
    FUNCTION get_current_period RETURN NUMBER IS
        v_period_id NUMBER;
    BEGIN
        SELECT PERIOD_ID INTO v_period_id
        FROM PAY_PERIODS
        WHERE SYSDATE BETWEEN PERIOD_START_DATE AND PERIOD_END_DATE
        AND STATUS = 'OPEN'
        AND ROWNUM = 1;

        RETURN v_period_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_current_period;

    -- -----------------------------------------------------------------------
    -- create_payroll_run
    -- -----------------------------------------------------------------------
    FUNCTION create_payroll_run(
        p_period_id IN NUMBER,
        p_run_type  IN VARCHAR2 DEFAULT 'REGULAR',
        p_user      IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_run_id  NUMBER;
        v_status  VARCHAR2(20);
    BEGIN
        -- Verify period is open
        SELECT STATUS INTO v_status
        FROM PAY_PERIODS
        WHERE PERIOD_ID = p_period_id;

        IF v_status = 'CLOSED' THEN
            RAISE_APPLICATION_ERROR(-20102,
                'Cannot create run for closed period: ' || p_period_id);
        END IF;

        SELECT SEQ_PAYROLL_RUN.NEXTVAL INTO v_run_id FROM DUAL;

        INSERT INTO PAYROLL_RUNS (
            RUN_ID, PERIOD_ID, RUN_TYPE, RUN_DATE,
            STATUS, SUBMITTED_BY, SUBMITTED_DATE,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_run_id, p_period_id, p_run_type, SYSDATE,
            'PENDING', p_user, SYSDATE,
            p_user, SYSDATE
        );

        RETURN v_run_id;
    END create_payroll_run;

    -- -----------------------------------------------------------------------
    -- calculate_payroll
    -- Main payroll calculation - processes all eligible employees
    -- NOTE: Row-by-row processing (cursor loop) - should be refactored
    -- to bulk processing for performance
    -- -----------------------------------------------------------------------
    PROCEDURE calculate_payroll(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
        v_period_id   NUMBER;
        v_run_type    VARCHAR2(20);
        v_emp_count   NUMBER := 0;
        v_error_count NUMBER := 0;
    BEGIN
        -- Get run details
        SELECT PERIOD_ID, RUN_TYPE INTO v_period_id, v_run_type
        FROM PAYROLL_RUNS
        WHERE RUN_ID = p_run_id;

        -- Update status to calculating
        UPDATE PAYROLL_RUNS
        SET STATUS = 'CALCULATING',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE RUN_ID = p_run_id;

        COMMIT;

        -- Process each active employee
        -- BUG: Cursor loop - should use BULK COLLECT + FORALL
        FOR emp_rec IN (
            SELECT e.EMP_ID
            FROM EMPLOYEES e
            WHERE e.EMPLOYMENT_STATUS = 'ACTIVE'
            AND e.ACTIVE_FLAG = 'Y'
            ORDER BY e.EMP_ID
        ) LOOP
            BEGIN
                calculate_employee_pay(p_run_id, emp_rec.EMP_ID, v_period_id, p_user);
                v_emp_count := v_emp_count + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;

                    -- Log error but continue processing other employees
                    INSERT INTO PAYROLL_DETAILS (
                        DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID,
                        ELEMENT_TYPE, AMOUNT, STATUS, ERROR_MESSAGE,
                        CREATED_BY, CREATED_DATE
                    ) VALUES (
                        SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, emp_rec.EMP_ID, 0,
                        'ERROR', 0, 'ERROR', SUBSTR(SQLERRM, 1, 4000),
                        p_user, SYSDATE
                    );
            END;

            -- Commit every 50 employees to avoid long transactions
            -- ISSUE: Partial commits mean a failure leaves payroll half-calculated
            IF MOD(v_emp_count, 50) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;

        -- Update run totals
        UPDATE PAYROLL_RUNS SET
            STATUS = CASE WHEN v_error_count > 0 THEN 'ERROR' ELSE 'CALCULATED' END,
            EMPLOYEE_COUNT = v_emp_count,
            ERROR_COUNT = v_error_count,
            TOTAL_GROSS = (SELECT NVL(SUM(AMOUNT), 0) FROM PAYROLL_DETAILS
                           WHERE RUN_ID = p_run_id AND ELEMENT_TYPE = 'EARNING' AND STATUS != 'ERROR'),
            TOTAL_DEDUCTIONS = (SELECT NVL(SUM(ABS(AMOUNT)), 0) FROM PAYROLL_DETAILS
                                WHERE RUN_ID = p_run_id AND ELEMENT_TYPE IN ('DEDUCTION', 'TAX') AND STATUS != 'ERROR'),
            TOTAL_NET = (SELECT NVL(SUM(CASE WHEN ELEMENT_TYPE = 'EARNING' THEN AMOUNT
                                             WHEN ELEMENT_TYPE IN ('DEDUCTION', 'TAX') THEN -ABS(AMOUNT)
                                             ELSE 0 END), 0)
                         FROM PAYROLL_DETAILS WHERE RUN_ID = p_run_id AND STATUS != 'ERROR'),
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE RUN_ID = p_run_id;

        COMMIT;
    END calculate_payroll;

    -- -----------------------------------------------------------------------
    -- calculate_employee_pay
    -- Calculates pay for a single employee in a given period
    -- -----------------------------------------------------------------------
    PROCEDURE calculate_employee_pay(
        p_run_id    IN NUMBER,
        p_emp_id    IN NUMBER,
        p_period_id IN NUMBER,
        p_user      IN VARCHAR2 DEFAULT USER
    ) IS
        v_annual_salary   NUMBER;
        v_period_gross    NUMBER;
        v_period_start    DATE;
        v_period_end      DATE;
        v_pay_frequency   VARCHAR2(20);
        v_periods_per_year NUMBER;
        v_taxable_income  NUMBER;
        v_federal_tax     NUMBER;
        v_state_tax       NUMBER;
        v_ss_tax          NUMBER;
        v_medicare_tax    NUMBER;
        v_ytd_gross       NUMBER;
        v_filing_status   VARCHAR2(30);
        v_fed_allowances  NUMBER;
        v_state_code      VARCHAR2(3);
        v_state_allowances NUMBER;
        v_addl_fed_wh     NUMBER;
        v_total_deductions NUMBER := 0;
    BEGIN
        -- Get period dates and frequency
        SELECT PERIOD_START_DATE, PERIOD_END_DATE, PAY_FREQUENCY
        INTO v_period_start, v_period_end, v_pay_frequency
        FROM PAY_PERIODS
        WHERE PERIOD_ID = p_period_id;

        -- Determine periods per year
        v_periods_per_year := CASE v_pay_frequency
            WHEN 'WEEKLY' THEN 52
            WHEN 'BIWEEKLY' THEN 26
            WHEN 'SEMIMONTHLY' THEN 24
            WHEN 'MONTHLY' THEN 12
            ELSE 12
        END;

        -- Get current annual salary
        v_annual_salary := get_salary_as_of(p_emp_id, v_period_end);

        IF v_annual_salary = 0 THEN
            RAISE_APPLICATION_ERROR(-20104,
                'No active salary record for employee ' || p_emp_id);
        END IF;

        -- Calculate gross pay for this period
        v_period_gross := ROUND(v_annual_salary / v_periods_per_year, 2);

        -- Insert gross pay earning
        INSERT INTO PAYROLL_DETAILS (
            DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
            AMOUNT, STATUS, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id, 1, 'EARNING',
            v_period_gross, 'CALCULATED', p_user, SYSDATE
        );

        -- Get YTD gross for tax calculations
        v_ytd_gross := get_ytd_earnings(p_emp_id, EXTRACT(YEAR FROM v_period_end));

        -- Get employee tax info
        BEGIN
            SELECT FILING_STATUS, FEDERAL_ALLOWANCES, STATE_CODE,
                   STATE_ALLOWANCES, ADDITIONAL_FED_WH
            INTO v_filing_status, v_fed_allowances, v_state_code,
                 v_state_allowances, v_addl_fed_wh
            FROM EMPLOYEE_TAX_INFO
            WHERE EMP_ID = p_emp_id
            AND TAX_YEAR = EXTRACT(YEAR FROM v_period_end)
            AND ACTIVE_FLAG = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Default values if no W-4 on file
                v_filing_status := 'SINGLE';
                v_fed_allowances := 0;
                v_state_code := NULL;
                v_state_allowances := 0;
                v_addl_fed_wh := 0;
        END;

        -- Calculate federal income tax
        v_taxable_income := v_period_gross; -- Simplified; should subtract pretax deductions
        v_federal_tax := calculate_federal_tax(
            v_taxable_income, v_filing_status, v_fed_allowances,
            v_addl_fed_wh, v_pay_frequency
        );

        IF v_federal_tax > 0 THEN
            INSERT INTO PAYROLL_DETAILS (
                DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
                AMOUNT, STATUS, CREATED_BY, CREATED_DATE
            ) VALUES (
                SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id, 100, 'TAX',
                -v_federal_tax, 'CALCULATED', p_user, SYSDATE
            );
            v_total_deductions := v_total_deductions + v_federal_tax;
        END IF;

        -- Calculate state tax
        IF v_state_code IS NOT NULL THEN
            v_state_tax := calculate_state_tax(
                v_taxable_income, v_state_code, v_filing_status,
                v_state_allowances, v_pay_frequency
            );

            IF v_state_tax > 0 THEN
                INSERT INTO PAYROLL_DETAILS (
                    DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
                    AMOUNT, STATUS, CREATED_BY, CREATED_DATE
                ) VALUES (
                    SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id, 101, 'TAX',
                    -v_state_tax, 'CALCULATED', p_user, SYSDATE
                );
                v_total_deductions := v_total_deductions + v_state_tax;
            END IF;
        END IF;

        -- Calculate FICA (Social Security)
        v_ss_tax := calculate_fica(v_period_gross, v_ytd_gross);

        IF v_ss_tax > 0 THEN
            INSERT INTO PAYROLL_DETAILS (
                DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
                AMOUNT, STATUS, CREATED_BY, CREATED_DATE
            ) VALUES (
                SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id, 102, 'TAX',
                -v_ss_tax, 'CALCULATED', p_user, SYSDATE
            );
            v_total_deductions := v_total_deductions + v_ss_tax;
        END IF;

        -- Calculate Medicare
        v_medicare_tax := calculate_medicare(v_period_gross, v_ytd_gross);

        IF v_medicare_tax > 0 THEN
            INSERT INTO PAYROLL_DETAILS (
                DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
                AMOUNT, STATUS, CREATED_BY, CREATED_DATE
            ) VALUES (
                SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id, 103, 'TAX',
                -v_medicare_tax, 'CALCULATED', p_user, SYSDATE
            );
            v_total_deductions := v_total_deductions + v_medicare_tax;
        END IF;

        -- Process employee-specific deductions (benefits, 401k, etc.)
        FOR ded_rec IN (
            SELECT epe.ELEMENT_ID, epe.AMOUNT, epe.PERCENTAGE,
                   epe.OVERRIDE_AMOUNT, pe.ELEMENT_CODE, pe.ELEMENT_TYPE,
                   pe.CALCULATION_TYPE, pe.DEFAULT_AMOUNT, pe.DEFAULT_PERCENTAGE,
                   pe.PRETAX_FLAG
            FROM EMPLOYEE_PAY_ELEMENTS epe
            JOIN PAY_ELEMENTS pe ON epe.ELEMENT_ID = pe.ELEMENT_ID
            WHERE epe.EMP_ID = p_emp_id
            AND epe.ACTIVE_FLAG = 'Y'
            AND pe.ELEMENT_TYPE IN ('DEDUCTION', 'BENEFIT')
            AND epe.EFFECTIVE_DATE <= v_period_end
            AND (epe.END_DATE IS NULL OR epe.END_DATE >= v_period_start)
            ORDER BY pe.PRIORITY_ORDER
        ) LOOP
            DECLARE
                v_ded_amount NUMBER;
            BEGIN
                -- Calculate deduction amount based on type
                IF ded_rec.OVERRIDE_AMOUNT IS NOT NULL THEN
                    v_ded_amount := ded_rec.OVERRIDE_AMOUNT;
                ELSIF ded_rec.CALCULATION_TYPE = 'FLAT' THEN
                    v_ded_amount := NVL(ded_rec.AMOUNT, ded_rec.DEFAULT_AMOUNT);
                ELSIF ded_rec.CALCULATION_TYPE = 'PERCENTAGE' THEN
                    v_ded_amount := ROUND(v_period_gross *
                        NVL(ded_rec.PERCENTAGE, ded_rec.DEFAULT_PERCENTAGE) / 100, 2);
                ELSE
                    v_ded_amount := NVL(ded_rec.AMOUNT, 0);
                END IF;

                IF v_ded_amount > 0 THEN
                    INSERT INTO PAYROLL_DETAILS (
                        DETAIL_ID, RUN_ID, EMP_ID, ELEMENT_ID, ELEMENT_TYPE,
                        AMOUNT, STATUS, CREATED_BY, CREATED_DATE
                    ) VALUES (
                        SEQ_PAYROLL_DETAIL.NEXTVAL, p_run_id, p_emp_id,
                        ded_rec.ELEMENT_ID, ded_rec.ELEMENT_TYPE,
                        -v_ded_amount, 'CALCULATED', p_user, SYSDATE
                    );
                    v_total_deductions := v_total_deductions + v_ded_amount;
                END IF;
            END;
        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
            PKG_COMMON.log_error('PKG_PAYROLL', 'calculate_employee_pay',
                'EMP_ID=' || p_emp_id || ': ' || SQLERRM, p_user);
            RAISE;
    END calculate_employee_pay;

    -- -----------------------------------------------------------------------
    -- approve_payroll
    -- -----------------------------------------------------------------------
    PROCEDURE approve_payroll(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT STATUS INTO v_status
        FROM PAYROLL_RUNS
        WHERE RUN_ID = p_run_id
        FOR UPDATE;

        IF v_status NOT IN ('CALCULATED') THEN
            RAISE_APPLICATION_ERROR(-20103,
                'Cannot approve run in status: ' || v_status);
        END IF;

        UPDATE PAYROLL_RUNS SET
            STATUS = 'APPROVED',
            APPROVED_BY = p_user,
            APPROVED_DATE = SYSDATE,
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE RUN_ID = p_run_id;
    END approve_payroll;

    -- -----------------------------------------------------------------------
    -- reverse_payroll
    -- -----------------------------------------------------------------------
    PROCEDURE reverse_payroll(
        p_run_id IN NUMBER,
        p_reason IN VARCHAR2,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE PAYROLL_RUNS SET
            STATUS = 'REVERSED',
            MODIFIED_BY = p_user,
            MODIFIED_DATE = SYSDATE
        WHERE RUN_ID = p_run_id;

        UPDATE PAYROLL_DETAILS SET
            STATUS = 'REVERSED'
        WHERE RUN_ID = p_run_id;

        PKG_AUDIT.log_action('PAYROLL_RUNS', p_run_id, 'UPDATE', p_user);
    END reverse_payroll;

    -- -----------------------------------------------------------------------
    -- calculate_federal_tax
    -- Uses progressive tax brackets
    -- NOTE: Hard-coded 2024 brackets - should read from TAX_BRACKETS table
    -- -----------------------------------------------------------------------
    FUNCTION calculate_federal_tax(
        p_taxable_income  IN NUMBER,
        p_filing_status   IN VARCHAR2,
        p_allowances      IN NUMBER DEFAULT 0,
        p_additional_wh   IN NUMBER DEFAULT 0,
        p_pay_frequency   IN VARCHAR2 DEFAULT 'MONTHLY'
    ) RETURN NUMBER IS
        v_annualized      NUMBER;
        v_std_deduction   NUMBER;
        v_taxable         NUMBER;
        v_tax             NUMBER := 0;
        v_periods         NUMBER;
    BEGIN
        v_periods := CASE p_pay_frequency
            WHEN 'WEEKLY' THEN 52
            WHEN 'BIWEEKLY' THEN 26
            WHEN 'SEMIMONTHLY' THEN 24
            WHEN 'MONTHLY' THEN 12
            ELSE 12
        END;

        -- Annualize the income
        v_annualized := p_taxable_income * v_periods;

        -- Subtract standard deduction and allowances
        v_std_deduction := CASE
            WHEN p_filing_status IN ('MARRIED_JOINT') THEN c_standard_deduction_married
            ELSE c_standard_deduction_single
        END;

        v_taxable := v_annualized - v_std_deduction - (p_allowances * c_allowance_amount);

        IF v_taxable <= 0 THEN
            RETURN 0;
        END IF;

        -- 2024 Federal tax brackets (Single)
        -- TODO: Read from TAX_BRACKETS table instead of hard-coding
        IF p_filing_status = 'SINGLE' OR p_filing_status = 'MARRIED_SEPARATE' THEN
            IF v_taxable <= 11600 THEN
                v_tax := v_taxable * 0.10;
            ELSIF v_taxable <= 47150 THEN
                v_tax := 1160 + (v_taxable - 11600) * 0.12;
            ELSIF v_taxable <= 100525 THEN
                v_tax := 5426 + (v_taxable - 47150) * 0.22;
            ELSIF v_taxable <= 191950 THEN
                v_tax := 17168.50 + (v_taxable - 100525) * 0.24;
            ELSIF v_taxable <= 243725 THEN
                v_tax := 39110.50 + (v_taxable - 191950) * 0.32;
            ELSIF v_taxable <= 609350 THEN
                v_tax := 55678.50 + (v_taxable - 243725) * 0.35;
            ELSE
                v_tax := 183647.25 + (v_taxable - 609350) * 0.37;
            END IF;
        ELSIF p_filing_status = 'MARRIED_JOINT' THEN
            IF v_taxable <= 23200 THEN
                v_tax := v_taxable * 0.10;
            ELSIF v_taxable <= 94300 THEN
                v_tax := 2320 + (v_taxable - 23200) * 0.12;
            ELSIF v_taxable <= 201050 THEN
                v_tax := 10852 + (v_taxable - 94300) * 0.22;
            ELSIF v_taxable <= 383900 THEN
                v_tax := 34337 + (v_taxable - 201050) * 0.24;
            ELSIF v_taxable <= 487450 THEN
                v_tax := 78221 + (v_taxable - 383900) * 0.32;
            ELSIF v_taxable <= 731200 THEN
                v_tax := 111357 + (v_taxable - 487450) * 0.35;
            ELSE
                v_tax := 196669.50 + (v_taxable - 731200) * 0.37;
            END IF;
        END IF;

        -- Convert back to per-period amount
        v_tax := ROUND(v_tax / v_periods, 2);

        -- Add additional withholding
        v_tax := v_tax + NVL(p_additional_wh, 0);

        RETURN v_tax;
    END calculate_federal_tax;

    -- -----------------------------------------------------------------------
    -- calculate_state_tax
    -- Simplified state tax - flat rate per state
    -- In production, each state would have its own bracket structure
    -- -----------------------------------------------------------------------
    FUNCTION calculate_state_tax(
        p_taxable_income  IN NUMBER,
        p_state_code      IN VARCHAR2,
        p_filing_status   IN VARCHAR2,
        p_allowances      IN NUMBER DEFAULT 0,
        p_pay_frequency   IN VARCHAR2 DEFAULT 'MONTHLY'
    ) RETURN NUMBER IS
        v_rate NUMBER;
    BEGIN
        -- Simplified flat rates by state (actual implementation would be bracket-based)
        v_rate := CASE p_state_code
            WHEN 'CA' THEN 0.0725
            WHEN 'NY' THEN 0.0685
            WHEN 'TX' THEN 0          -- No state income tax
            WHEN 'FL' THEN 0          -- No state income tax
            WHEN 'WA' THEN 0          -- No state income tax
            WHEN 'IL' THEN 0.0495
            WHEN 'PA' THEN 0.0307
            WHEN 'OH' THEN 0.04
            WHEN 'NJ' THEN 0.0637
            WHEN 'MA' THEN 0.05
            ELSE 0.05                  -- Default rate for unknown states
        END;

        RETURN ROUND(p_taxable_income * v_rate, 2);
    END calculate_state_tax;

    -- -----------------------------------------------------------------------
    -- calculate_fica (Social Security)
    -- -----------------------------------------------------------------------
    FUNCTION calculate_fica(
        p_gross_pay   IN NUMBER,
        p_ytd_gross   IN NUMBER
    ) RETURN NUMBER IS
        v_taxable NUMBER;
    BEGIN
        IF p_ytd_gross >= c_ss_wage_base_2024 THEN
            RETURN 0; -- Already exceeded wage base
        END IF;

        v_taxable := LEAST(p_gross_pay, c_ss_wage_base_2024 - p_ytd_gross);
        RETURN ROUND(v_taxable * c_ss_rate, 2);
    END calculate_fica;

    -- -----------------------------------------------------------------------
    -- calculate_medicare
    -- -----------------------------------------------------------------------
    FUNCTION calculate_medicare(
        p_gross_pay   IN NUMBER,
        p_ytd_gross   IN NUMBER
    ) RETURN NUMBER IS
        v_base_tax NUMBER;
        v_addl_tax NUMBER := 0;
    BEGIN
        v_base_tax := ROUND(p_gross_pay * c_medicare_rate, 2);

        -- Additional Medicare tax on high earners
        IF p_ytd_gross + p_gross_pay > c_medicare_addl_threshold THEN
            IF p_ytd_gross >= c_medicare_addl_threshold THEN
                v_addl_tax := ROUND(p_gross_pay * c_medicare_addl_rate, 2);
            ELSE
                v_addl_tax := ROUND(
                    (p_ytd_gross + p_gross_pay - c_medicare_addl_threshold) * c_medicare_addl_rate, 2);
            END IF;
        END IF;

        RETURN v_base_tax + v_addl_tax;
    END calculate_medicare;

    -- -----------------------------------------------------------------------
    -- get_payslip
    -- -----------------------------------------------------------------------
    PROCEDURE get_payslip(
        p_cursor  OUT t_payslip_cursor,
        p_run_id  IN NUMBER,
        p_emp_id  IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT pd.EMP_ID,
                   e.EMP_NUMBER,
                   e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
                   pp.PERIOD_NAME,
                   SUM(CASE WHEN pd.ELEMENT_TYPE = 'EARNING' THEN pd.AMOUNT ELSE 0 END) AS GROSS_PAY,
                   SUM(CASE WHEN pd.ELEMENT_TYPE IN ('DEDUCTION', 'TAX', 'BENEFIT')
                            THEN ABS(pd.AMOUNT) ELSE 0 END) AS TOTAL_DEDUCTIONS,
                   SUM(pd.AMOUNT) AS NET_PAY,
                   SUM(CASE WHEN pd.ELEMENT_ID = 100 THEN ABS(pd.AMOUNT) ELSE 0 END) AS FEDERAL_TAX,
                   SUM(CASE WHEN pd.ELEMENT_ID = 101 THEN ABS(pd.AMOUNT) ELSE 0 END) AS STATE_TAX,
                   SUM(CASE WHEN pd.ELEMENT_ID = 102 THEN ABS(pd.AMOUNT) ELSE 0 END) AS SOCIAL_SECURITY,
                   SUM(CASE WHEN pd.ELEMENT_ID = 103 THEN ABS(pd.AMOUNT) ELSE 0 END) AS MEDICARE,
                   0 AS YTD_GROSS,  -- Placeholder
                   0 AS YTD_NET     -- Placeholder
            FROM PAYROLL_DETAILS pd
            JOIN EMPLOYEES e ON pd.EMP_ID = e.EMP_ID
            JOIN PAYROLL_RUNS pr ON pd.RUN_ID = pr.RUN_ID
            JOIN PAY_PERIODS pp ON pr.PERIOD_ID = pp.PERIOD_ID
            WHERE pd.RUN_ID = p_run_id
            AND pd.STATUS != 'ERROR'
            AND (p_emp_id IS NULL OR pd.EMP_ID = p_emp_id)
            GROUP BY pd.EMP_ID, e.EMP_NUMBER,
                     e.FIRST_NAME || ' ' || e.LAST_NAME,
                     pp.PERIOD_NAME
            ORDER BY e.LAST_NAME;
    END get_payslip;

    -- -----------------------------------------------------------------------
    -- get_ytd_earnings
    -- -----------------------------------------------------------------------
    FUNCTION get_ytd_earnings(
        p_emp_id    IN NUMBER,
        p_tax_year  IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_ytd NUMBER;
    BEGIN
        SELECT NVL(SUM(pd.AMOUNT), 0)
        INTO v_ytd
        FROM PAYROLL_DETAILS pd
        JOIN PAYROLL_RUNS pr ON pd.RUN_ID = pr.RUN_ID
        JOIN PAY_PERIODS pp ON pr.PERIOD_ID = pp.PERIOD_ID
        WHERE pd.EMP_ID = p_emp_id
        AND pd.ELEMENT_TYPE = 'EARNING'
        AND pd.STATUS = 'CALCULATED'
        AND EXTRACT(YEAR FROM pp.PERIOD_START_DATE) = p_tax_year;

        RETURN v_ytd;
    END get_ytd_earnings;

    -- -----------------------------------------------------------------------
    -- generate_pay_register
    -- Writes pay register to UTL_FILE output
    -- LEGACY: Uses flat file output - should be replaced with modern reporting
    -- -----------------------------------------------------------------------
    PROCEDURE generate_pay_register(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    ) IS
        v_file     UTL_FILE.FILE_TYPE;
        v_filename VARCHAR2(100);
        v_period   VARCHAR2(50);
    BEGIN
        SELECT pp.PERIOD_NAME INTO v_period
        FROM PAYROLL_RUNS pr
        JOIN PAY_PERIODS pp ON pr.PERIOD_ID = pp.PERIOD_ID
        WHERE pr.RUN_ID = p_run_id;

        v_filename := 'PAY_REGISTER_' || p_run_id || '_' ||
                       TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') || '.csv';

        v_file := UTL_FILE.FOPEN('PAYROLL_OUTPUT', v_filename, 'W', 32767);

        -- Header
        UTL_FILE.PUT_LINE(v_file,
            'EMP_NUMBER,EMPLOYEE_NAME,DEPARTMENT,GROSS_PAY,FED_TAX,STATE_TAX,SS_TAX,MEDICARE,DEDUCTIONS,NET_PAY');

        -- Detail lines
        FOR rec IN (
            SELECT e.EMP_NUMBER,
                   e.FIRST_NAME || ' ' || e.LAST_NAME AS EMP_NAME,
                   d.DEPT_NAME,
                   SUM(CASE WHEN pd.ELEMENT_TYPE = 'EARNING' THEN pd.AMOUNT ELSE 0 END) AS GROSS,
                   SUM(CASE WHEN pd.ELEMENT_ID = 100 THEN ABS(pd.AMOUNT) ELSE 0 END) AS FED,
                   SUM(CASE WHEN pd.ELEMENT_ID = 101 THEN ABS(pd.AMOUNT) ELSE 0 END) AS STATE,
                   SUM(CASE WHEN pd.ELEMENT_ID = 102 THEN ABS(pd.AMOUNT) ELSE 0 END) AS SS,
                   SUM(CASE WHEN pd.ELEMENT_ID = 103 THEN ABS(pd.AMOUNT) ELSE 0 END) AS MED,
                   SUM(CASE WHEN pd.ELEMENT_TYPE IN ('DEDUCTION', 'BENEFIT')
                            THEN ABS(pd.AMOUNT) ELSE 0 END) AS DEDS,
                   SUM(pd.AMOUNT) AS NET
            FROM PAYROLL_DETAILS pd
            JOIN EMPLOYEES e ON pd.EMP_ID = e.EMP_ID
            JOIN DEPARTMENTS d ON e.DEPT_ID = d.DEPT_ID
            WHERE pd.RUN_ID = p_run_id
            AND pd.STATUS != 'ERROR'
            GROUP BY e.EMP_NUMBER, e.FIRST_NAME || ' ' || e.LAST_NAME, d.DEPT_NAME
            ORDER BY e.LAST_NAME
        ) LOOP
            UTL_FILE.PUT_LINE(v_file,
                rec.EMP_NUMBER || ',' ||
                '"' || rec.EMP_NAME || '",' ||
                '"' || rec.DEPT_NAME || '",' ||
                TO_CHAR(rec.GROSS, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.FED, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.STATE, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.SS, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.MED, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.DEDS, 'FM999999990.00') || ',' ||
                TO_CHAR(rec.NET, 'FM999999990.00')
            );
        END LOOP;

        UTL_FILE.FCLOSE(v_file);

        DBMS_OUTPUT.PUT_LINE('Pay register generated: ' || v_filename);

    EXCEPTION
        WHEN OTHERS THEN
            IF UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;
            PKG_COMMON.log_error('PKG_PAYROLL', 'generate_pay_register', SQLERRM, p_user);
            RAISE;
    END generate_pay_register;

END PKG_PAYROLL;
/
