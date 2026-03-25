CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_VALIDATION AS
-- ============================================================================
-- UT_PKG_VALIDATION - Unit Tests for PKG_VALIDATION Body
-- ============================================================================

    g_test_grade_id    NUMBER;
    g_test_emp_id      NUMBER;
    g_test_holiday_id  NUMBER;

    PROCEDURE setup_test_data IS
    BEGIN
        -- Insert test job grade
        INSERT INTO JOB_GRADES (GRADE_ID, GRADE_NAME, MIN_SALARY, MAX_SALARY)
        VALUES (9999, 'UT_TEST_GRADE', 50000, 150000)
        RETURNING GRADE_ID INTO g_test_grade_id;

        -- Insert a test holiday
        INSERT INTO HOLIDAYS (HOLIDAY_ID, HOLIDAY_NAME, HOLIDAY_DATE,
            ACTIVE_FLAG, LOCATION_CODE)
        VALUES (SEQ_HOLIDAY.NEXTVAL, 'UT Test Holiday',
            TO_DATE('2024-12-25', 'YYYY-MM-DD'), 'Y', NULL)
        RETURNING HOLIDAY_ID INTO g_test_holiday_id;

        -- Insert a location-specific holiday
        INSERT INTO HOLIDAYS (HOLIDAY_ID, HOLIDAY_NAME, HOLIDAY_DATE,
            ACTIVE_FLAG, LOCATION_CODE)
        VALUES (SEQ_HOLIDAY.NEXTVAL, 'UT Regional Holiday',
            TO_DATE('2024-07-04', 'YYYY-MM-DD'), 'Y', 'US-NY');

        -- Insert test employee with all required fields
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-999901', 'UTTest', 'Employee',
            SYSDATE, 1, 1, 'ut_valid_emp@test.com', 'ACTIVE', 'Y',
            'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO g_test_emp_id;

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-999901';
        DELETE FROM JOB_GRADES WHERE GRADE_ID = 9999;
        DELETE FROM HOLIDAYS WHERE HOLIDAY_NAME LIKE 'UT %';
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- validate_date_range Tests
    -- ===================================================================
    PROCEDURE test_date_range_valid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(
            TO_DATE('2024-01-01', 'YYYY-MM-DD'),
            TO_DATE('2024-12-31', 'YYYY-MM-DD')
        )).to_be_true();
    END test_date_range_valid;

    PROCEDURE test_date_range_equal IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(
            TO_DATE('2024-06-15', 'YYYY-MM-DD'),
            TO_DATE('2024-06-15', 'YYYY-MM-DD')
        )).to_be_true();
    END test_date_range_equal;

    PROCEDURE test_date_range_inverted IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(
            TO_DATE('2024-12-31', 'YYYY-MM-DD'),
            TO_DATE('2024-01-01', 'YYYY-MM-DD')
        )).to_be_false();
    END test_date_range_inverted;

    PROCEDURE test_date_range_null_start IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(
            NULL,
            TO_DATE('2024-12-31', 'YYYY-MM-DD')
        )).to_be_false();
    END test_date_range_null_start;

    PROCEDURE test_date_range_null_end IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(
            TO_DATE('2024-01-01', 'YYYY-MM-DD'),
            NULL
        )).to_be_false();
    END test_date_range_null_end;

    PROCEDURE test_date_range_both_null IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_date_range(NULL, NULL)).to_be_false();
    END test_date_range_both_null;

    -- ===================================================================
    -- validate_salary_for_grade Tests
    -- ===================================================================
    PROCEDURE test_salary_valid IS
    BEGIN
        ut.expect(
            PKG_VALIDATION.validate_salary_for_grade(75000, g_test_grade_id)
        ).to_be_null();
    END test_salary_valid;

    PROCEDURE test_salary_below_min IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_salary_for_grade(10000, g_test_grade_id);
        ut.expect(v_result).to_be_like('%below minimum%');
    END test_salary_below_min;

    PROCEDURE test_salary_above_max IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_salary_for_grade(200000, g_test_grade_id);
        ut.expect(v_result).to_be_like('%exceeds maximum%');
    END test_salary_above_max;

    PROCEDURE test_salary_null_salary IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_salary_for_grade(NULL, g_test_grade_id);
        ut.expect(v_result).to_equal('Salary and grade are required');
    END test_salary_null_salary;

    PROCEDURE test_salary_null_grade IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_salary_for_grade(75000, NULL);
        ut.expect(v_result).to_equal('Salary and grade are required');
    END test_salary_null_grade;

    PROCEDURE test_salary_invalid_grade IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_salary_for_grade(75000, -999);
        ut.expect(v_result).to_be_like('%Invalid grade ID%');
    END test_salary_invalid_grade;

    PROCEDURE test_salary_at_minimum IS
    BEGIN
        ut.expect(
            PKG_VALIDATION.validate_salary_for_grade(50000, g_test_grade_id)
        ).to_be_null();
    END test_salary_at_minimum;

    PROCEDURE test_salary_at_maximum IS
    BEGIN
        ut.expect(
            PKG_VALIDATION.validate_salary_for_grade(150000, g_test_grade_id)
        ).to_be_null();
    END test_salary_at_maximum;

    -- ===================================================================
    -- validate_email_format Tests
    -- ===================================================================
    PROCEDURE test_email_valid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_email_format('user@example.com')).to_be_true();
    END test_email_valid;

    PROCEDURE test_email_invalid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_email_format('invalid_email')).to_be_false();
    END test_email_invalid;

    PROCEDURE test_email_null IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_email_format(NULL)).to_be_false();
    END test_email_null;

    -- ===================================================================
    -- validate_phone_format Tests
    -- ===================================================================
    PROCEDURE test_phone_valid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_phone_format('5551234567')).to_be_true();
    END test_phone_valid;

    PROCEDURE test_phone_invalid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_phone_format('123')).to_be_false();
    END test_phone_invalid;

    -- ===================================================================
    -- validate_emp_number_format Tests
    -- ===================================================================
    PROCEDURE test_emp_number_valid IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_emp_number_format('EMP-123456')).to_be_true();
    END test_emp_number_valid;

    PROCEDURE test_emp_number_bad_prefix IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_emp_number_format('ABC-123456')).to_be_false();
    END test_emp_number_bad_prefix;

    PROCEDURE test_emp_number_short IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_emp_number_format('EMP-123')).to_be_false();
    END test_emp_number_short;

    PROCEDURE test_emp_number_long IS
    BEGIN
        ut.expect(PKG_VALIDATION.validate_emp_number_format('EMP-1234567')).to_be_false();
    END test_emp_number_long;

    -- ===================================================================
    -- is_future_date Tests
    -- ===================================================================
    PROCEDURE test_future_date_tomorrow IS
    BEGIN
        ut.expect(PKG_VALIDATION.is_future_date(TRUNC(SYSDATE) + 1)).to_be_true();
    END test_future_date_tomorrow;

    PROCEDURE test_future_date_today IS
    BEGIN
        ut.expect(PKG_VALIDATION.is_future_date(TRUNC(SYSDATE))).to_be_false();
    END test_future_date_today;

    PROCEDURE test_future_date_yesterday IS
    BEGIN
        ut.expect(PKG_VALIDATION.is_future_date(TRUNC(SYSDATE) - 1)).to_be_false();
    END test_future_date_yesterday;

    -- ===================================================================
    -- is_business_day Tests
    -- ===================================================================
    PROCEDURE test_business_day_weekday IS
    BEGIN
        -- 2024-01-08 is a Monday
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-01-08', 'YYYY-MM-DD')
        )).to_be_true();
    END test_business_day_weekday;

    PROCEDURE test_business_day_saturday IS
    BEGIN
        -- 2024-01-13 is a Saturday
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-01-13', 'YYYY-MM-DD')
        )).to_be_false();
    END test_business_day_saturday;

    PROCEDURE test_business_day_sunday IS
    BEGIN
        -- 2024-01-14 is a Sunday
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-01-14', 'YYYY-MM-DD')
        )).to_be_false();
    END test_business_day_sunday;

    PROCEDURE test_business_day_holiday IS
    BEGIN
        -- 2024-12-25 is our test holiday (Wednesday)
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-12-25', 'YYYY-MM-DD')
        )).to_be_false();
    END test_business_day_holiday;

    PROCEDURE test_business_day_no_holiday IS
    BEGIN
        -- 2024-12-26 is a Thursday, not a holiday
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-12-26', 'YYYY-MM-DD')
        )).to_be_true();
    END test_business_day_no_holiday;

    PROCEDURE test_business_day_location IS
    BEGIN
        -- 2024-07-04 is a holiday only for US-NY
        ut.expect(PKG_VALIDATION.is_business_day(
            TO_DATE('2024-07-04', 'YYYY-MM-DD'), 'US-NY'
        )).to_be_false();
    END test_business_day_location;

    -- ===================================================================
    -- validate_required_fields Tests
    -- ===================================================================
    PROCEDURE test_required_fields_valid IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_required_fields('EMPLOYEES', g_test_emp_id);
        ut.expect(v_result).to_be_null();
    END test_required_fields_valid;

    PROCEDURE test_required_fields_missing IS
        v_result VARCHAR2(4000);
        v_temp_emp_id NUMBER;
    BEGIN
        -- Insert employee missing FIRST_NAME
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-999902', NULL, 'TestLast',
            SYSDATE, 1, 1, 'ut_missing@test.com', 'ACTIVE', 'Y',
            'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO v_temp_emp_id;

        v_result := PKG_VALIDATION.validate_required_fields('EMPLOYEES', v_temp_emp_id);
        ut.expect(v_result).to_equal('First Name is required');

        DELETE FROM EMPLOYEES WHERE EMP_ID = v_temp_emp_id;
        COMMIT;
    END test_required_fields_missing;

    PROCEDURE test_required_fields_not_found IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_required_fields('EMPLOYEES', -999);
        ut.expect(v_result).to_equal('Record not found');
    END test_required_fields_not_found;

    PROCEDURE test_required_fields_unknown_table IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_VALIDATION.validate_required_fields('UNKNOWN_TABLE', 1);
        ut.expect(v_result).to_be_null();
    END test_required_fields_unknown_table;

END UT_PKG_VALIDATION;
/
