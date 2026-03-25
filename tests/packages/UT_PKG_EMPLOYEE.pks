CREATE OR REPLACE PACKAGE HRMS.UT_PKG_EMPLOYEE AS
-- ============================================================================
-- UT_PKG_EMPLOYEE - Unit Tests for PKG_EMPLOYEE
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_EMPLOYEE body
-- ============================================================================

    --%suite(PKG_EMPLOYEE - Employee Management Package)
    --%suitepath(hrms.employee)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- generate_emp_number Tests
    -- -------------------------------------------------------------------
    --%test(generate_emp_number returns EMP-NNNNNN format)
    PROCEDURE test_gen_emp_number_format;

    --%test(generate_emp_number returns sequential number)
    PROCEDURE test_gen_emp_number_sequential;

    --%test(generate_emp_number fallback uses sequence)
    PROCEDURE test_gen_emp_number_fallback;

    -- -------------------------------------------------------------------
    -- create_employee Tests
    -- -------------------------------------------------------------------
    --%test(create_employee creates new employee with required fields)
    PROCEDURE test_create_emp_basic;

    --%test(create_employee raises error for NULL first name)
    PROCEDURE test_create_emp_null_name;

    --%test(create_employee raises error for invalid department)
    PROCEDURE test_create_emp_bad_dept;

    --%test(create_employee raises error for invalid job)
    PROCEDURE test_create_emp_bad_job;

    --%test(create_employee creates salary record when salary provided)
    PROCEDURE test_create_emp_with_salary;

    --%test(create_employee defaults location from department)
    PROCEDURE test_create_emp_default_location;

    --%test(create_employee converts names to uppercase)
    PROCEDURE test_create_emp_uppercase_names;

    --%test(create_employee converts email to lowercase)
    PROCEDURE test_create_emp_lowercase_email;

    --%test(create_employee logs audit trail)
    PROCEDURE test_create_emp_audit;

    --%test(create_employee sends welcome notification)
    PROCEDURE test_create_emp_notification;

    --%test(create_employee notifies manager when specified)
    PROCEDURE test_create_emp_notify_manager;

    -- -------------------------------------------------------------------
    -- update_employee Tests
    -- -------------------------------------------------------------------
    --%test(update_employee updates partial fields)
    PROCEDURE test_update_emp_partial;

    --%test(update_employee raises error for non-existent employee)
    PROCEDURE test_update_emp_not_found;

    --%test(update_employee preserves unchanged fields)
    PROCEDURE test_update_emp_preserves_fields;

    -- -------------------------------------------------------------------
    -- get_employee Tests
    -- -------------------------------------------------------------------
    --%test(get_employee returns employee record)
    PROCEDURE test_get_emp_basic;

    --%test(get_employee raises error for non-existent employee)
    PROCEDURE test_get_emp_not_found;

    -- -------------------------------------------------------------------
    -- get_employee_by_number Tests
    -- -------------------------------------------------------------------
    --%test(get_employee_by_number returns employee by EMP-NNNNNN)
    PROCEDURE test_get_emp_by_number;

    --%test(get_employee_by_number raises error for invalid number)
    PROCEDURE test_get_emp_by_number_not_found;

    -- -------------------------------------------------------------------
    -- search_employees Tests
    -- -------------------------------------------------------------------
    --%test(search_employees returns cursor with matching records)
    PROCEDURE test_search_basic;

    --%test(search_employees filters by last name)
    PROCEDURE test_search_by_name;

    --%test(search_employees filters by department)
    PROCEDURE test_search_by_dept;

    --%test(search_employees filters by status)
    PROCEDURE test_search_by_status;

    --%test(search_employees filters by hire date range)
    PROCEDURE test_search_by_date_range;

    -- -------------------------------------------------------------------
    -- transfer_employee Tests
    -- -------------------------------------------------------------------
    --%test(transfer_employee moves employee to new department)
    PROCEDURE test_transfer_basic;

    --%test(transfer_employee raises error for non-active employee)
    PROCEDURE test_transfer_non_active;

    --%test(transfer_employee raises error for invalid department)
    PROCEDURE test_transfer_bad_dept;

    --%test(transfer_employee logs history)
    PROCEDURE test_transfer_history;

    -- -------------------------------------------------------------------
    -- promote_employee Tests
    -- -------------------------------------------------------------------
    --%test(promote_employee updates job and creates salary record)
    PROCEDURE test_promote_basic;

    --%test(promote_employee logs history with salary change)
    PROCEDURE test_promote_history;

    -- -------------------------------------------------------------------
    -- terminate_employee Tests
    -- -------------------------------------------------------------------
    --%test(terminate_employee sets status to TERMINATED)
    PROCEDURE test_terminate_basic;

    --%test(terminate_employee raises error for already terminated)
    PROCEDURE test_terminate_already_done;

    --%test(terminate_employee cancels pending leave requests)
    PROCEDURE test_terminate_cancels_leave;

    --%test(terminate_employee deactivates salary records)
    PROCEDURE test_terminate_deactivates_salary;

    -- -------------------------------------------------------------------
    -- rehire_employee Tests
    -- -------------------------------------------------------------------
    --%test(rehire_employee reactivates terminated employee)
    PROCEDURE test_rehire_basic;

    --%test(rehire_employee raises error for non-existent employee)
    PROCEDURE test_rehire_not_found;

    -- -------------------------------------------------------------------
    -- Query Functions Tests
    -- -------------------------------------------------------------------
    --%test(get_direct_reports returns list of direct reports)
    PROCEDURE test_direct_reports;

    --%test(get_direct_reports returns empty for no reports)
    PROCEDURE test_direct_reports_empty;

    --%test(get_org_chart returns hierarchy cursor)
    PROCEDURE test_org_chart;

    --%test(get_headcount_by_dept counts active employees)
    PROCEDURE test_headcount;

    --%test(get_headcount_by_dept with NULL dept returns total)
    PROCEDURE test_headcount_all;

    --%test(get_tenure_years calculates tenure correctly)
    PROCEDURE test_tenure_years;

    --%test(get_tenure_years returns NULL for non-existent employee)
    PROCEDURE test_tenure_not_found;

    -- -------------------------------------------------------------------
    -- Validation / Utility Tests
    -- -------------------------------------------------------------------
    --%test(is_active returns TRUE for active employee)
    PROCEDURE test_is_active_true;

    --%test(is_active returns FALSE for terminated employee)
    PROCEDURE test_is_active_false;

    --%test(is_active returns FALSE for non-existent employee)
    PROCEDURE test_is_active_not_found;

    --%test(validate_employee returns TRUE for valid employee)
    PROCEDURE test_validate_emp_valid;

    --%test(validate_employee returns FALSE for non-existent)
    PROCEDURE test_validate_emp_not_found;

    --%test(emp_exists returns TRUE for existing employee)
    PROCEDURE test_emp_exists_true;

    --%test(emp_exists returns FALSE for non-existent employee)
    PROCEDURE test_emp_exists_false;

    --%test(set_session_context sets package variables)
    PROCEDURE test_set_session_context;

    --%test(set_session_context handles non-existent employee)
    PROCEDURE test_set_context_not_found;

END UT_PKG_EMPLOYEE;
/
