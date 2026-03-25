CREATE OR REPLACE PACKAGE HRMS.UT_PKG_PAYROLL AS
-- ============================================================================
-- UT_PKG_PAYROLL - Unit Tests for PKG_PAYROLL
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_PAYROLL body
-- ============================================================================

    --%suite(PKG_PAYROLL - Payroll Processing Package)
    --%suitepath(hrms.payroll)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    --%test(create_salary_record inserts new salary record)
    PROCEDURE test_create_salary_basic;

    --%test(create_salary_record deactivates previous active record)
    PROCEDURE test_create_salary_deactivate_prev;

    --%test(create_salary_record raises -20101 for non-positive salary)
    PROCEDURE test_create_salary_negative;

    --%test(create_salary_record records change_reason)
    PROCEDURE test_create_salary_reason;

    --%test(create_salary_record records change_pct)
    PROCEDURE test_create_salary_change_pct;

    --%test(get_current_salary returns active salary)
    PROCEDURE test_get_salary_active;

    --%test(get_current_salary returns 0 for no salary record)
    PROCEDURE test_get_salary_no_record;

    --%test(get_salary_as_of returns salary effective at given date)
    PROCEDURE test_get_salary_as_of;

    --%test(get_salary_as_of returns 0 for date with no record)
    PROCEDURE test_get_salary_as_of_none;

    --%test(create_pay_periods generates 12 monthly periods for a year)
    PROCEDURE test_create_periods_monthly;

    --%test(create_pay_periods generates biweekly periods)
    PROCEDURE test_create_periods_biweekly;

    --%test(close_pay_period sets status to CLOSED)
    PROCEDURE test_close_period_basic;

    --%test(close_pay_period raises -20102 for already closed period)
    PROCEDURE test_close_period_already_closed;

    --%test(get_current_period returns open period containing SYSDATE)
    PROCEDURE test_get_current_period;

    --%test(create_payroll_run creates run for open period)
    PROCEDURE test_create_run_basic;

    --%test(create_payroll_run raises -20102 for closed period)
    PROCEDURE test_create_run_closed_period;

    --%test(calculate_federal_tax computes tax for single filer)
    PROCEDURE test_fed_tax_single;

    --%test(calculate_federal_tax computes tax for married joint filer)
    PROCEDURE test_fed_tax_married;

    --%test(calculate_federal_tax returns 0 for zero income)
    PROCEDURE test_fed_tax_zero_income;

    --%test(calculate_federal_tax applies allowances deduction)
    PROCEDURE test_fed_tax_with_allowances;

    --%test(calculate_federal_tax adds additional withholding)
    PROCEDURE test_fed_tax_additional_wh;

    --%test(calculate_federal_tax adjusts for biweekly frequency)
    PROCEDURE test_fed_tax_biweekly;

    --%test(calculate_federal_tax handles high income bracket)
    PROCEDURE test_fed_tax_high_income;

    --%test(calculate_federal_tax handles married separate filing)
    PROCEDURE test_fed_tax_married_separate;

    --%test(calculate_state_tax returns correct value for CA)
    PROCEDURE test_state_tax_ca;

    --%test(calculate_state_tax returns 0 for TX no-tax state)
    PROCEDURE test_state_tax_tx;

    --%test(calculate_state_tax returns default rate for unknown state)
    PROCEDURE test_state_tax_unknown;

    --%test(calculate_state_tax returns correct value for NY)
    PROCEDURE test_state_tax_ny;

    --%test(calculate_fica returns 6.2 pct of income)
    PROCEDURE test_fica_basic;

    --%test(calculate_fica returns 0 when YTD exceeds wage base)
    PROCEDURE test_fica_over_cap;

    --%test(calculate_fica caps when approaching wage base)
    PROCEDURE test_fica_near_cap;

    --%test(calculate_medicare returns 1.45 pct of income)
    PROCEDURE test_medicare_basic;

    --%test(calculate_medicare applies additional 0.9 pct when YTD above threshold)
    PROCEDURE test_medicare_additional_full;

    --%test(calculate_medicare applies partial additional when crossing threshold)
    PROCEDURE test_medicare_additional_partial;

    --%test(calculate_payroll processes employees for a run)
    PROCEDURE test_calc_payroll_basic;

    --%test(approve_payroll sets status to APPROVED for CALCULATED run)
    PROCEDURE test_approve_payroll;

    --%test(approve_payroll raises -20103 for non-CALCULATED status)
    PROCEDURE test_approve_wrong_status;

    --%test(reverse_payroll sets run and details to REVERSED)
    PROCEDURE test_reverse_payroll;

    --%test(get_payslip returns cursor with payslip data)
    PROCEDURE test_get_payslip_cursor;

    --%test(get_ytd_earnings returns 0 when no payroll details exist)
    PROCEDURE test_ytd_earnings_zero;

END UT_PKG_PAYROLL;
/
