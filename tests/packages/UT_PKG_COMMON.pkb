CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_COMMON AS
-- ============================================================================
-- UT_PKG_COMMON - Unit Tests for PKG_COMMON Body
-- ============================================================================

    -- Test data constants
    c_test_group CONSTANT VARCHAR2(30) := 'UT_TEST_GROUP';
    c_test_code  CONSTANT VARCHAR2(30) := 'UT_TEST_CODE';
    c_test_value CONSTANT VARCHAR2(100) := 'test_value_123';

    PROCEDURE setup_test_data IS
    BEGIN
        -- Insert test system parameters for config tests
        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, c_test_code, c_test_value,
            'Y', 'UT_SETUP', SYSDATE
        );

        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, 'UT_NUM_CODE', '42',
            'Y', 'UT_SETUP', SYSDATE
        );

        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, 'UT_DATE_CODE', '2024-06-15',
            'Y', 'UT_SETUP', SYSDATE
        );

        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, 'UT_READONLY', 'readonly_val',
            'N', 'UT_SETUP', SYSDATE
        );

        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, 'UT_BAD_NUM', 'not_a_number',
            'Y', 'UT_SETUP', SYSDATE
        );

        INSERT INTO SYSTEM_PARAMETERS (
            PARAM_ID, PARAM_GROUP, PARAM_CODE, PARAM_VALUE,
            EDITABLE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_SYS_PARAM.NEXTVAL, c_test_group, 'UT_BAD_DATE', 'not_a_date',
            'Y', 'UT_SETUP', SYSDATE
        );

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM SYSTEM_PARAMETERS WHERE PARAM_GROUP = c_test_group;
        DELETE FROM AUDIT_LOG WHERE CHANGED_BY = 'UT_TEST_USER';
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- Logging Tests
    -- ===================================================================
    PROCEDURE test_log_error_basic IS
        v_count NUMBER;
    BEGIN
        PKG_COMMON.log_error('UT_PKG', 'test_proc', 'Test error message', 'UT_TEST_USER');

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = 'ERROR_LOG'
        AND CHANGED_BY = 'UT_TEST_USER'
        AND NEW_VALUES LIKE '%UT_PKG%test_proc%';

        ut.expect(v_count).to_be_greater_than(0);
    END test_log_error_basic;

    PROCEDURE test_log_error_special_chars IS
        v_count NUMBER;
    BEGIN
        PKG_COMMON.log_error('UT_PKG', 'test_proc',
            'Error with "quotes" and special chars: <>&', 'UT_TEST_USER');

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = 'ERROR_LOG'
        AND CHANGED_BY = 'UT_TEST_USER';

        ut.expect(v_count).to_be_greater_than(0);
    END test_log_error_special_chars;

    PROCEDURE test_log_error_autonomous IS
        v_count_before NUMBER;
        v_count_after  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count_before
        FROM AUDIT_LOG WHERE TABLE_NAME = 'ERROR_LOG';

        SAVEPOINT before_log_test;

        PKG_COMMON.log_error('UT_PKG', 'autonomous_test', 'Should persist', 'UT_TEST_USER');

        ROLLBACK TO before_log_test;

        -- The log_error uses AUTONOMOUS_TRANSACTION so it should persist
        SELECT COUNT(*) INTO v_count_after
        FROM AUDIT_LOG WHERE TABLE_NAME = 'ERROR_LOG';

        ut.expect(v_count_after).to_be_greater_than(v_count_before);
    END test_log_error_autonomous;

    PROCEDURE test_log_error_fallback IS
    BEGIN
        -- When AUDIT_LOG insert fails, should fall back to DBMS_OUTPUT
        -- We test that the procedure doesn't raise an exception
        DBMS_OUTPUT.ENABLE(1000000);
        PKG_COMMON.log_error('UT_PKG', 'fallback_test',
            RPAD('X', 5000, 'X'), 'UT_TEST_USER');

        -- If we reach here, the procedure handled the error gracefully
        ut.expect(TRUE).to_be_true();
    END test_log_error_fallback;

    PROCEDURE test_log_info_basic IS
        v_count NUMBER;
    BEGIN
        PKG_COMMON.log_info('UT_PKG', 'test_info', 'Test info message', 'UT_TEST_USER');

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = 'INFO_LOG'
        AND CHANGED_BY = 'UT_TEST_USER';

        ut.expect(v_count).to_be_greater_than(0);
    END test_log_info_basic;

    PROCEDURE test_log_info_default_user IS
        v_count NUMBER;
    BEGIN
        PKG_COMMON.log_info('UT_PKG', 'default_user_test', 'Msg with default user');

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = 'INFO_LOG'
        AND CHANGED_BY = USER;

        ut.expect(v_count).to_be_greater_than(0);
    END test_log_info_default_user;

    -- ===================================================================
    -- Configuration Tests
    -- ===================================================================
    PROCEDURE test_get_param_existing IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_COMMON.get_param(c_test_group, c_test_code);
        ut.expect(v_result).to_equal(c_test_value);
    END test_get_param_existing;

    PROCEDURE test_get_param_not_found IS
        v_result VARCHAR2(4000);
    BEGIN
        v_result := PKG_COMMON.get_param('NONEXISTENT_GROUP', 'NONEXISTENT_CODE');
        ut.expect(v_result).to_be_null();
    END test_get_param_not_found;

    PROCEDURE test_get_param_number_valid IS
        v_result NUMBER;
    BEGIN
        v_result := PKG_COMMON.get_param_number(c_test_group, 'UT_NUM_CODE');
        ut.expect(v_result).to_equal(42);
    END test_get_param_number_valid;

    PROCEDURE test_get_param_number_invalid IS
        v_result NUMBER;
    BEGIN
        v_result := PKG_COMMON.get_param_number(c_test_group, 'UT_BAD_NUM');
        ut.expect(v_result).to_be_null();
    END test_get_param_number_invalid;

    PROCEDURE test_get_param_date_valid IS
        v_result DATE;
    BEGIN
        v_result := PKG_COMMON.get_param_date(c_test_group, 'UT_DATE_CODE');
        ut.expect(v_result).to_equal(TO_DATE('2024-06-15', 'YYYY-MM-DD'));
    END test_get_param_date_valid;

    PROCEDURE test_get_param_date_invalid IS
        v_result DATE;
    BEGIN
        v_result := PKG_COMMON.get_param_date(c_test_group, 'UT_BAD_DATE');
        ut.expect(v_result).to_be_null();
    END test_get_param_date_invalid;

    PROCEDURE test_set_param_editable IS
        v_result VARCHAR2(4000);
    BEGIN
        PKG_COMMON.set_param(c_test_group, c_test_code, 'updated_value', 'UT_TEST_USER');
        v_result := PKG_COMMON.get_param(c_test_group, c_test_code);
        ut.expect(v_result).to_equal('updated_value');

        -- Restore original value
        PKG_COMMON.set_param(c_test_group, c_test_code, c_test_value, 'UT_TEST_USER');
    END test_set_param_editable;

    PROCEDURE test_set_param_not_editable IS
    BEGIN
        PKG_COMMON.set_param(c_test_group, 'UT_READONLY', 'new_value', 'UT_TEST_USER');
        ut.fail('Expected ORA-20900 but no exception was raised');
    EXCEPTION
        WHEN OTHERS THEN
            ut.expect(SQLCODE).to_equal(-20900);
    END test_set_param_not_editable;

    PROCEDURE test_set_param_not_found IS
    BEGIN
        PKG_COMMON.set_param('NONEXISTENT', 'NONEXISTENT', 'val', 'UT_TEST_USER');
        ut.fail('Expected ORA-20900 but no exception was raised');
    EXCEPTION
        WHEN OTHERS THEN
            ut.expect(SQLCODE).to_equal(-20900);
    END test_set_param_not_found;

    -- ===================================================================
    -- Date Utility Tests
    -- ===================================================================
    PROCEDURE test_business_days_weekdays IS
        v_result NUMBER;
    BEGIN
        -- Monday 2024-01-08 to Friday 2024-01-12 = 5 weekdays
        v_result := PKG_COMMON.business_days_between(
            TO_DATE('2024-01-08', 'YYYY-MM-DD'),
            TO_DATE('2024-01-12', 'YYYY-MM-DD')
        );
        ut.expect(v_result).to_equal(5);
    END test_business_days_weekdays;

    PROCEDURE test_business_days_weekend_only IS
        v_result NUMBER;
    BEGIN
        -- Saturday 2024-01-13 to Sunday 2024-01-14 = 0 weekdays
        v_result := PKG_COMMON.business_days_between(
            TO_DATE('2024-01-13', 'YYYY-MM-DD'),
            TO_DATE('2024-01-14', 'YYYY-MM-DD')
        );
        ut.expect(v_result).to_equal(0);
    END test_business_days_weekend_only;

    PROCEDURE test_business_days_same_day IS
        v_result NUMBER;
    BEGIN
        -- Monday to Monday = 1 weekday
        v_result := PKG_COMMON.business_days_between(
            TO_DATE('2024-01-08', 'YYYY-MM-DD'),
            TO_DATE('2024-01-08', 'YYYY-MM-DD')
        );
        ut.expect(v_result).to_equal(1);
    END test_business_days_same_day;

    PROCEDURE test_business_days_full_week IS
        v_result NUMBER;
    BEGIN
        -- Mon Jan 8 to Sun Jan 14 = 5 weekdays
        v_result := PKG_COMMON.business_days_between(
            TO_DATE('2024-01-08', 'YYYY-MM-DD'),
            TO_DATE('2024-01-14', 'YYYY-MM-DD')
        );
        ut.expect(v_result).to_equal(5);
    END test_business_days_full_week;

    PROCEDURE test_add_business_days_skip_weekends IS
        v_result DATE;
    BEGIN
        -- Starting Thursday 2024-01-11, add 3 business days = Tuesday 2024-01-16
        v_result := PKG_COMMON.add_business_days(
            TO_DATE('2024-01-11', 'YYYY-MM-DD'), 3);
        ut.expect(v_result).to_equal(TO_DATE('2024-01-16', 'YYYY-MM-DD'));
    END test_add_business_days_skip_weekends;

    PROCEDURE test_add_business_days_from_friday IS
        v_result DATE;
    BEGIN
        -- Starting Friday 2024-01-12, add 1 business day = Monday 2024-01-15
        v_result := PKG_COMMON.add_business_days(
            TO_DATE('2024-01-12', 'YYYY-MM-DD'), 1);
        ut.expect(v_result).to_equal(TO_DATE('2024-01-15', 'YYYY-MM-DD'));
    END test_add_business_days_from_friday;

    PROCEDURE test_add_business_days_zero IS
        v_result DATE;
    BEGIN
        -- Adding 0 business days returns the same date (truncated)
        v_result := PKG_COMMON.add_business_days(
            TO_DATE('2024-01-08', 'YYYY-MM-DD'), 0);
        ut.expect(v_result).to_equal(TO_DATE('2024-01-08', 'YYYY-MM-DD'));
    END test_add_business_days_zero;

    PROCEDURE test_fiscal_year_q1 IS
        v_result NUMBER;
    BEGIN
        -- October 2024 -> FY 2025
        v_result := PKG_COMMON.get_fiscal_year(TO_DATE('2024-10-15', 'YYYY-MM-DD'));
        ut.expect(v_result).to_equal(2025);
    END test_fiscal_year_q1;

    PROCEDURE test_fiscal_year_q2_to_q4 IS
        v_result NUMBER;
    BEGIN
        -- March 2024 -> FY 2024
        v_result := PKG_COMMON.get_fiscal_year(TO_DATE('2024-03-15', 'YYYY-MM-DD'));
        ut.expect(v_result).to_equal(2024);
    END test_fiscal_year_q2_to_q4;

    PROCEDURE test_fiscal_quarter_q1 IS
    BEGIN
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-10-15', 'YYYY-MM-DD'))).to_equal(1);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-11-15', 'YYYY-MM-DD'))).to_equal(1);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-12-15', 'YYYY-MM-DD'))).to_equal(1);
    END test_fiscal_quarter_q1;

    PROCEDURE test_fiscal_quarter_q2 IS
    BEGIN
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-01-15', 'YYYY-MM-DD'))).to_equal(2);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-02-15', 'YYYY-MM-DD'))).to_equal(2);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-03-15', 'YYYY-MM-DD'))).to_equal(2);
    END test_fiscal_quarter_q2;

    PROCEDURE test_fiscal_quarter_q3 IS
    BEGIN
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-04-15', 'YYYY-MM-DD'))).to_equal(3);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-05-15', 'YYYY-MM-DD'))).to_equal(3);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-06-15', 'YYYY-MM-DD'))).to_equal(3);
    END test_fiscal_quarter_q3;

    PROCEDURE test_fiscal_quarter_q4 IS
    BEGIN
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-07-15', 'YYYY-MM-DD'))).to_equal(4);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-08-15', 'YYYY-MM-DD'))).to_equal(4);
        ut.expect(PKG_COMMON.get_fiscal_quarter(TO_DATE('2024-09-15', 'YYYY-MM-DD'))).to_equal(4);
    END test_fiscal_quarter_q4;

    -- ===================================================================
    -- Formatting Tests
    -- ===================================================================
    PROCEDURE test_format_phone_10digit IS
    BEGIN
        ut.expect(PKG_COMMON.format_phone('5551234567')).to_equal('(555) 123-4567');
    END test_format_phone_10digit;

    PROCEDURE test_format_phone_11digit IS
    BEGIN
        ut.expect(PKG_COMMON.format_phone('15551234567')).to_equal('+1 (555) 123-4567');
    END test_format_phone_11digit;

    PROCEDURE test_format_phone_nonstandard IS
    BEGIN
        ut.expect(PKG_COMMON.format_phone('12345')).to_equal('12345');
    END test_format_phone_nonstandard;

    PROCEDURE test_format_phone_strip_chars IS
    BEGIN
        ut.expect(PKG_COMMON.format_phone('(555) 123-4567')).to_equal('(555) 123-4567');
    END test_format_phone_strip_chars;

    PROCEDURE test_format_ssn_masked_valid IS
    BEGIN
        ut.expect(PKG_COMMON.format_ssn_masked('123456789')).to_equal('***-**-6789');
    END test_format_ssn_masked_valid;

    PROCEDURE test_format_ssn_masked_null IS
    BEGIN
        ut.expect(PKG_COMMON.format_ssn_masked(NULL)).to_equal('***-**-****');
    END test_format_ssn_masked_null;

    PROCEDURE test_format_ssn_masked_short IS
    BEGIN
        ut.expect(PKG_COMMON.format_ssn_masked('12')).to_equal('***-**-****');
    END test_format_ssn_masked_short;

    PROCEDURE test_format_currency_usd IS
    BEGIN
        ut.expect(PKG_COMMON.format_currency(1234.56, 'USD')).to_equal('$1,234.56');
    END test_format_currency_usd;

    PROCEDURE test_format_currency_eur IS
    BEGIN
        ut.expect(PKG_COMMON.format_currency(1234.56, 'EUR')).to_equal(CHR(8364) || '1,234.56');
    END test_format_currency_eur;

    PROCEDURE test_format_currency_gbp IS
    BEGIN
        ut.expect(PKG_COMMON.format_currency(1234.56, 'GBP')).to_equal(CHR(163) || '1,234.56');
    END test_format_currency_gbp;

    PROCEDURE test_format_currency_unknown IS
    BEGIN
        ut.expect(PKG_COMMON.format_currency(100.00, 'JPY')).to_equal('JPY 100.00');
    END test_format_currency_unknown;

    PROCEDURE test_format_currency_large_amount IS
    BEGIN
        ut.expect(PKG_COMMON.format_currency(1234567.89, 'USD')).to_equal('$1,234,567.89');
    END test_format_currency_large_amount;

    PROCEDURE test_format_name_fl IS
    BEGIN
        ut.expect(PKG_COMMON.format_name('john', 'doe', 'FL')).to_equal('John Doe');
    END test_format_name_fl;

    PROCEDURE test_format_name_lf IS
    BEGIN
        ut.expect(PKG_COMMON.format_name('john', 'doe', 'LF')).to_equal('Doe, John');
    END test_format_name_lf;

    PROCEDURE test_format_name_initcap IS
    BEGIN
        ut.expect(PKG_COMMON.format_name('JANE', 'SMITH')).to_equal('Jane Smith');
    END test_format_name_initcap;

    -- ===================================================================
    -- Validation Tests
    -- ===================================================================
    PROCEDURE test_valid_email_true IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_email('user@example.com')).to_be_true();
    END test_valid_email_true;

    PROCEDURE test_valid_email_no_at IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_email('userexample.com')).to_be_false();
    END test_valid_email_no_at;

    PROCEDURE test_valid_email_no_domain IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_email('user@')).to_be_false();
    END test_valid_email_no_domain;

    PROCEDURE test_valid_email_null IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_email(NULL)).to_be_false();
    END test_valid_email_null;

    PROCEDURE test_valid_phone_true IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_phone('5551234567')).to_be_true();
    END test_valid_phone_true;

    PROCEDURE test_valid_phone_too_short IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_phone('12345')).to_be_false();
    END test_valid_phone_too_short;

    PROCEDURE test_valid_phone_11digit IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_phone('15551234567')).to_be_true();
    END test_valid_phone_11digit;

    PROCEDURE test_valid_ssn_true IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_ssn('123456789')).to_be_true();
    END test_valid_ssn_true;

    PROCEDURE test_valid_ssn_formatted IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_ssn('123-45-6789')).to_be_true();
    END test_valid_ssn_formatted;

    PROCEDURE test_valid_ssn_too_short IS
    BEGIN
        ut.expect(PKG_COMMON.is_valid_ssn('12345')).to_be_false();
    END test_valid_ssn_too_short;

END UT_PKG_COMMON;
/
