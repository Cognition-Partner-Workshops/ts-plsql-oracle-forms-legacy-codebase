CREATE OR REPLACE PACKAGE HRMS.UT_PKG_VALIDATION AS
-- ============================================================================
-- UT_PKG_VALIDATION - Unit Tests for PKG_VALIDATION
-- Framework: utPLSQL v3
-- Coverage target: >85% of PKG_VALIDATION body
-- ============================================================================

    --%suite(PKG_VALIDATION - Centralized Validation Package)
    --%suitepath(hrms.validation)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- validate_date_range Tests
    -- -------------------------------------------------------------------
    --%test(validate_date_range returns TRUE for valid range)
    PROCEDURE test_date_range_valid;

    --%test(validate_date_range returns TRUE when dates are equal)
    PROCEDURE test_date_range_equal;

    --%test(validate_date_range returns FALSE when end < start)
    PROCEDURE test_date_range_inverted;

    --%test(validate_date_range returns FALSE when start date is NULL)
    PROCEDURE test_date_range_null_start;

    --%test(validate_date_range returns FALSE when end date is NULL)
    PROCEDURE test_date_range_null_end;

    --%test(validate_date_range returns FALSE when both dates are NULL)
    PROCEDURE test_date_range_both_null;

    -- -------------------------------------------------------------------
    -- validate_salary_for_grade Tests
    -- -------------------------------------------------------------------
    --%test(validate_salary_for_grade returns NULL for valid salary within range)
    PROCEDURE test_salary_valid;

    --%test(validate_salary_for_grade returns error for salary below minimum)
    PROCEDURE test_salary_below_min;

    --%test(validate_salary_for_grade returns error for salary above maximum)
    PROCEDURE test_salary_above_max;

    --%test(validate_salary_for_grade returns error for NULL salary)
    PROCEDURE test_salary_null_salary;

    --%test(validate_salary_for_grade returns error for NULL grade_id)
    PROCEDURE test_salary_null_grade;

    --%test(validate_salary_for_grade returns error for non-existent grade)
    PROCEDURE test_salary_invalid_grade;

    --%test(validate_salary_for_grade returns NULL for salary at exact minimum)
    PROCEDURE test_salary_at_minimum;

    --%test(validate_salary_for_grade returns NULL for salary at exact maximum)
    PROCEDURE test_salary_at_maximum;

    -- -------------------------------------------------------------------
    -- validate_email_format Tests
    -- -------------------------------------------------------------------
    --%test(validate_email_format returns TRUE for valid email)
    PROCEDURE test_email_valid;

    --%test(validate_email_format returns FALSE for invalid email)
    PROCEDURE test_email_invalid;

    --%test(validate_email_format returns FALSE for NULL email)
    PROCEDURE test_email_null;

    -- -------------------------------------------------------------------
    -- validate_phone_format Tests
    -- -------------------------------------------------------------------
    --%test(validate_phone_format returns TRUE for valid phone)
    PROCEDURE test_phone_valid;

    --%test(validate_phone_format returns FALSE for invalid phone)
    PROCEDURE test_phone_invalid;

    -- -------------------------------------------------------------------
    -- validate_emp_number_format Tests
    -- -------------------------------------------------------------------
    --%test(validate_emp_number_format returns TRUE for valid EMP-NNNNNN)
    PROCEDURE test_emp_number_valid;

    --%test(validate_emp_number_format returns FALSE for wrong prefix)
    PROCEDURE test_emp_number_bad_prefix;

    --%test(validate_emp_number_format returns FALSE for too few digits)
    PROCEDURE test_emp_number_short;

    --%test(validate_emp_number_format returns FALSE for too many digits)
    PROCEDURE test_emp_number_long;

    -- -------------------------------------------------------------------
    -- is_future_date Tests
    -- -------------------------------------------------------------------
    --%test(is_future_date returns TRUE for tomorrow)
    PROCEDURE test_future_date_tomorrow;

    --%test(is_future_date returns FALSE for today)
    PROCEDURE test_future_date_today;

    --%test(is_future_date returns FALSE for yesterday)
    PROCEDURE test_future_date_yesterday;

    -- -------------------------------------------------------------------
    -- is_business_day Tests
    -- -------------------------------------------------------------------
    --%test(is_business_day returns TRUE for a weekday)
    PROCEDURE test_business_day_weekday;

    --%test(is_business_day returns FALSE for Saturday)
    PROCEDURE test_business_day_saturday;

    --%test(is_business_day returns FALSE for Sunday)
    PROCEDURE test_business_day_sunday;

    --%test(is_business_day returns FALSE for a holiday)
    PROCEDURE test_business_day_holiday;

    --%test(is_business_day returns TRUE for non-holiday weekday)
    PROCEDURE test_business_day_no_holiday;

    --%test(is_business_day with location_code filters holidays)
    PROCEDURE test_business_day_location;

    -- -------------------------------------------------------------------
    -- validate_required_fields Tests
    -- -------------------------------------------------------------------
    --%test(validate_required_fields returns NULL when all fields populated)
    PROCEDURE test_required_fields_valid;

    --%test(validate_required_fields returns error for missing fields)
    PROCEDURE test_required_fields_missing;

    --%test(validate_required_fields returns error for non-existent record)
    PROCEDURE test_required_fields_not_found;

    --%test(validate_required_fields returns NULL for unknown table)
    PROCEDURE test_required_fields_unknown_table;

END UT_PKG_VALIDATION;
/
