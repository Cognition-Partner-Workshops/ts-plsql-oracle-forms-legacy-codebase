CREATE OR REPLACE PACKAGE HRMS.UT_TRG_EMPLOYEES AS
-- ============================================================================
-- UT_TRG_EMPLOYEES - Unit Tests for Employee Triggers
-- Framework: utPLSQL v3
-- Tests: TRG_EMP_BEFORE_INSERT, TRG_EMP_BEFORE_UPDATE, TRG_EMP_INSTEAD_OF_DELETE
-- ============================================================================

    --%suite(TRG_EMPLOYEES - Employee Table Triggers)
    --%suitepath(hrms.triggers)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- TRG_EMP_BEFORE_INSERT Tests
    -- -------------------------------------------------------------------
    --%test(Insert trigger sets CREATED_BY and CREATED_DATE)
    PROCEDURE test_insert_audit_cols;

    --%test(Insert trigger validates hire date is not in the future beyond threshold)
    PROCEDURE test_insert_future_hire;

    --%test(Insert trigger enforces unique email)
    PROCEDURE test_insert_dup_email;

    --%test(Insert trigger sets default EMPLOYMENT_STATUS to ACTIVE)
    PROCEDURE test_insert_default_status;

    --%test(Insert trigger generates EMP_NUMBER if not provided)
    PROCEDURE test_insert_gen_emp_number;

    -- -------------------------------------------------------------------
    -- TRG_EMP_BEFORE_UPDATE Tests
    -- -------------------------------------------------------------------
    --%test(Update trigger sets MODIFIED_BY and MODIFIED_DATE)
    PROCEDURE test_update_audit_cols;

    --%test(Update trigger prevents reactivation of terminated employees)
    PROCEDURE test_update_reactivate_terminated;

    --%test(Update trigger logs status change to EMPLOYEE_HISTORY)
    PROCEDURE test_update_status_change_hist;

    --%test(Update trigger logs department change to EMPLOYEE_HISTORY)
    PROCEDURE test_update_dept_change_hist;

    --%test(Update trigger logs job change to EMPLOYEE_HISTORY)
    PROCEDURE test_update_job_change_hist;

    -- -------------------------------------------------------------------
    -- TRG_EMP_INSTEAD_OF_DELETE Tests
    -- -------------------------------------------------------------------
    --%test(Delete trigger prevents direct deletion of employee records)
    PROCEDURE test_delete_prevented;

END UT_TRG_EMPLOYEES;
/
