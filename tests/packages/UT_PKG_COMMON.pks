CREATE OR REPLACE PACKAGE HRMS.UT_PKG_COMMON AS
-- ============================================================================
-- UT_PKG_COMMON - Unit Tests for PKG_COMMON
-- Framework: utPLSQL v3
-- Coverage target: >85% of PKG_COMMON body
-- ============================================================================

    --%suite(PKG_COMMON - Shared Utility Package)
    --%suitepath(hrms.common)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- Logging Tests
    -- -------------------------------------------------------------------
    --%test(log_error inserts an audit record with ERROR_LOG table name)
    PROCEDURE test_log_error_basic;

    --%test(log_error handles special characters in message)
    PROCEDURE test_log_error_special_chars;

    --%test(log_error uses autonomous transaction and does not affect caller)
    PROCEDURE test_log_error_autonomous;

    --%test(log_error falls back to DBMS_OUTPUT on insert failure)
    PROCEDURE test_log_error_fallback;

    --%test(log_info inserts an audit record with INFO_LOG table name)
    PROCEDURE test_log_info_basic;

    --%test(log_info defaults user to current USER)
    PROCEDURE test_log_info_default_user;

    -- -------------------------------------------------------------------
    -- Configuration Tests
    -- -------------------------------------------------------------------
    --%test(get_param returns value for existing parameter)
    PROCEDURE test_get_param_existing;

    --%test(get_param returns NULL for non-existent parameter)
    PROCEDURE test_get_param_not_found;

    --%test(get_param_number converts string to number)
    PROCEDURE test_get_param_number_valid;

    --%test(get_param_number returns NULL for non-numeric value)
    PROCEDURE test_get_param_number_invalid;

    --%test(get_param_date converts string to date)
    PROCEDURE test_get_param_date_valid;

    --%test(get_param_date returns NULL for invalid date format)
    PROCEDURE test_get_param_date_invalid;

    --%test(set_param updates editable parameter value)
    PROCEDURE test_set_param_editable;

    --%test(set_param raises error for non-editable parameter)
    PROCEDURE test_set_param_not_editable;

    --%test(set_param raises error for non-existent parameter)
    PROCEDURE test_set_param_not_found;

    -- -------------------------------------------------------------------
    -- Date Utility Tests
    -- -------------------------------------------------------------------
    --%test(business_days_between counts only weekdays)
    PROCEDURE test_business_days_weekdays;

    --%test(business_days_between returns 0 for weekend-only range)
    PROCEDURE test_business_days_weekend_only;

    --%test(business_days_between handles same-day range)
    PROCEDURE test_business_days_same_day;

    --%test(business_days_between handles full week correctly - 5 days)
    PROCEDURE test_business_days_full_week;

    --%test(add_business_days skips weekends)
    PROCEDURE test_add_business_days_skip_weekends;

    --%test(add_business_days with Friday start lands on following week)
    PROCEDURE test_add_business_days_from_friday;

    --%test(add_business_days with zero days returns same day)
    PROCEDURE test_add_business_days_zero;

    --%test(get_fiscal_year returns next year for Oct-Dec)
    PROCEDURE test_fiscal_year_q1;

    --%test(get_fiscal_year returns current year for Jan-Sep)
    PROCEDURE test_fiscal_year_q2_to_q4;

    --%test(get_fiscal_quarter returns Q1 for Oct-Dec)
    PROCEDURE test_fiscal_quarter_q1;

    --%test(get_fiscal_quarter returns Q2 for Jan-Mar)
    PROCEDURE test_fiscal_quarter_q2;

    --%test(get_fiscal_quarter returns Q3 for Apr-Jun)
    PROCEDURE test_fiscal_quarter_q3;

    --%test(get_fiscal_quarter returns Q4 for Jul-Sep)
    PROCEDURE test_fiscal_quarter_q4;

    -- -------------------------------------------------------------------
    -- Formatting Tests
    -- -------------------------------------------------------------------
    --%test(format_phone formats 10-digit US number)
    PROCEDURE test_format_phone_10digit;

    --%test(format_phone formats 11-digit US number with country code)
    PROCEDURE test_format_phone_11digit;

    --%test(format_phone returns original for non-standard length)
    PROCEDURE test_format_phone_nonstandard;

    --%test(format_phone strips non-numeric characters before formatting)
    PROCEDURE test_format_phone_strip_chars;

    --%test(format_ssn_masked returns masked SSN with last 4 digits)
    PROCEDURE test_format_ssn_masked_valid;

    --%test(format_ssn_masked returns full mask for NULL input)
    PROCEDURE test_format_ssn_masked_null;

    --%test(format_ssn_masked returns full mask for short input)
    PROCEDURE test_format_ssn_masked_short;

    --%test(format_currency adds USD dollar sign)
    PROCEDURE test_format_currency_usd;

    --%test(format_currency adds EUR symbol)
    PROCEDURE test_format_currency_eur;

    --%test(format_currency adds GBP symbol)
    PROCEDURE test_format_currency_gbp;

    --%test(format_currency uses code prefix for unknown currency)
    PROCEDURE test_format_currency_unknown;

    --%test(format_currency formats with comma separators)
    PROCEDURE test_format_currency_large_amount;

    --%test(format_name returns First Last by default)
    PROCEDURE test_format_name_fl;

    --%test(format_name returns Last, First when LF specified)
    PROCEDURE test_format_name_lf;

    --%test(format_name applies INITCAP to names)
    PROCEDURE test_format_name_initcap;

    -- -------------------------------------------------------------------
    -- Validation Tests
    -- -------------------------------------------------------------------
    --%test(is_valid_email returns TRUE for valid email)
    PROCEDURE test_valid_email_true;

    --%test(is_valid_email returns FALSE for missing @ sign)
    PROCEDURE test_valid_email_no_at;

    --%test(is_valid_email returns FALSE for missing domain)
    PROCEDURE test_valid_email_no_domain;

    --%test(is_valid_email returns FALSE for NULL input)
    PROCEDURE test_valid_email_null;

    --%test(is_valid_phone returns TRUE for valid 10-digit phone)
    PROCEDURE test_valid_phone_true;

    --%test(is_valid_phone returns FALSE for too-short number)
    PROCEDURE test_valid_phone_too_short;

    --%test(is_valid_phone returns TRUE for 11-digit number)
    PROCEDURE test_valid_phone_11digit;

    --%test(is_valid_ssn returns TRUE for valid 9-digit SSN)
    PROCEDURE test_valid_ssn_true;

    --%test(is_valid_ssn returns TRUE for formatted SSN with dashes)
    PROCEDURE test_valid_ssn_formatted;

    --%test(is_valid_ssn returns FALSE for too-short SSN)
    PROCEDURE test_valid_ssn_too_short;

END UT_PKG_COMMON;
/
