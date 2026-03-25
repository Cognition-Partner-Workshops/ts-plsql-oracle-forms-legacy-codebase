CREATE OR REPLACE PACKAGE HRMS.UT_PKG_REPORTING AS
-- ============================================================================
-- UT_PKG_REPORTING - Unit Tests for PKG_REPORTING
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_REPORTING body
-- ============================================================================

    --%suite(PKG_REPORTING - Report Generation Package)
    --%suitepath(hrms.reporting)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    --%test(headcount_report returns cursor with data)
    PROCEDURE test_headcount_basic;

    --%test(headcount_report filters by department)
    PROCEDURE test_headcount_by_dept;

    --%test(headcount_report filters by location)
    PROCEDURE test_headcount_by_location;

    --%test(headcount_report accepts as_of_date parameter)
    PROCEDURE test_headcount_as_of;

    --%test(compensation_summary returns cursor with salary data)
    PROCEDURE test_compensation_basic;

    --%test(compensation_summary filters by department)
    PROCEDURE test_compensation_by_dept;

    --%test(compensation_summary filters by grade)
    PROCEDURE test_compensation_by_grade;

    --%test(turnover_report returns cursor for date range)
    PROCEDURE test_turnover_basic;

    --%test(turnover_report filters by department)
    PROCEDURE test_turnover_by_dept;

    --%test(new_hires_report returns cursor for date range)
    PROCEDURE test_new_hires_basic;

    --%test(new_hires_report filters by department)
    PROCEDURE test_new_hires_by_dept;

    --%test(leave_utilization_report returns leave usage data)
    PROCEDURE test_leave_util_basic;

    --%test(leave_utilization_report filters by department)
    PROCEDURE test_leave_util_by_dept;

    --%test(payroll_summary_report returns payroll data for period)
    PROCEDURE test_payroll_summary;

    --%test(eeo_compliance_report returns compliance data)
    PROCEDURE test_eeo_compliance;

    --%test(refresh_reporting_tables completes without error)
    PROCEDURE test_refresh_tables;

END UT_PKG_REPORTING;
/
