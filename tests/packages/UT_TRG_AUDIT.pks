CREATE OR REPLACE PACKAGE HRMS.UT_TRG_AUDIT AS
-- ============================================================================
-- UT_TRG_AUDIT - Unit Tests for Generic Audit Triggers
-- Framework: utPLSQL v3
-- Tests: TRG_SALARY_AUDIT, TRG_LEAVE_REQUEST_AUDIT, TRG_DEPARTMENT_AUDIT
-- ============================================================================

    --%suite(TRG_AUDIT - Generic Audit Triggers)
    --%suitepath(hrms.triggers)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- TRG_SALARY_AUDIT Tests
    -- -------------------------------------------------------------------
    --%test(Salary insert triggers audit log entry with INSERT action)
    PROCEDURE test_salary_insert_audit;

    --%test(Salary update triggers audit log entry with UPDATE action)
    PROCEDURE test_salary_update_audit;

    --%test(Salary audit captures old and new JSON values)
    PROCEDURE test_salary_audit_json;

    -- -------------------------------------------------------------------
    -- TRG_LEAVE_REQUEST_AUDIT Tests
    -- -------------------------------------------------------------------
    --%test(Leave request status change triggers audit log entry)
    PROCEDURE test_leave_status_audit;

    --%test(Leave request audit captures old and new status in JSON)
    PROCEDURE test_leave_audit_json;

    -- -------------------------------------------------------------------
    -- TRG_DEPARTMENT_AUDIT Tests
    -- -------------------------------------------------------------------
    --%test(Department insert triggers audit log entry)
    PROCEDURE test_dept_insert_audit;

    --%test(Department update triggers audit log entry)
    PROCEDURE test_dept_update_audit;

    --%test(Department delete triggers audit log entry)
    PROCEDURE test_dept_delete_audit;

END UT_TRG_AUDIT;
/
