CREATE OR REPLACE PACKAGE HRMS.UT_PKG_SECURITY AS
-- ============================================================================
-- UT_PKG_SECURITY - Unit Tests for PKG_SECURITY
-- Framework: utPLSQL v3
-- Coverage target: >85% of PKG_SECURITY body
-- ============================================================================

    --%suite(PKG_SECURITY - Authentication & Authorization Package)
    --%suitepath(hrms.security)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- hash_password Tests
    -- -------------------------------------------------------------------
    --%test(hash_password returns consistent MD5 hash for same input)
    PROCEDURE test_hash_consistent;

    --%test(hash_password returns different hashes for different passwords)
    PROCEDURE test_hash_different;

    --%test(hash_password returns hex string)
    PROCEDURE test_hash_hex_format;

    --%test(hash_password returns 32-char hex for MD5)
    PROCEDURE test_hash_length;

    -- -------------------------------------------------------------------
    -- authenticate Tests
    -- -------------------------------------------------------------------
    --%test(authenticate creates session for valid credentials)
    PROCEDURE test_auth_valid;

    --%test(authenticate raises -20301 for non-existent user)
    PROCEDURE test_auth_bad_user;

    --%test(authenticate raises -20301 for inactive employee)
    PROCEDURE test_auth_inactive;

    --%test(authenticate handles duplicate email by using MIN emp_id)
    PROCEDURE test_auth_duplicate_email;

    --%test(authenticate stores IP address in session record)
    PROCEDURE test_auth_ip_stored;

    --%test(authenticate is case-insensitive for username)
    PROCEDURE test_auth_case_insensitive;

    -- -------------------------------------------------------------------
    -- logout Tests
    -- -------------------------------------------------------------------
    --%test(logout sets session status to CLOSED)
    PROCEDURE test_logout_status;

    --%test(logout sets logout_time)
    PROCEDURE test_logout_time;

    --%test(logout does not raise for non-existent session)
    PROCEDURE test_logout_nonexistent;

    -- -------------------------------------------------------------------
    -- is_session_valid Tests
    -- -------------------------------------------------------------------
    --%test(is_session_valid returns TRUE for active session)
    PROCEDURE test_session_valid_active;

    --%test(is_session_valid returns FALSE for closed session)
    PROCEDURE test_session_valid_closed;

    --%test(is_session_valid returns FALSE for expired session)
    PROCEDURE test_session_valid_expired;

    --%test(is_session_valid auto-expires timed-out session)
    PROCEDURE test_session_auto_expire;

    --%test(is_session_valid returns FALSE for non-existent session)
    PROCEDURE test_session_nonexistent;

    -- -------------------------------------------------------------------
    -- has_permission Tests
    -- -------------------------------------------------------------------
    --%test(has_permission returns TRUE for senior management grade >= 8)
    PROCEDURE test_perm_senior_mgmt;

    --%test(has_permission returns TRUE for mid-level VIEW action)
    PROCEDURE test_perm_mid_level_view;

    --%test(has_permission returns TRUE for LEAVE CREATE for all)
    PROCEDURE test_perm_leave_create;

    --%test(has_permission returns TRUE for EMPLOYEE VIEW for all)
    PROCEDURE test_perm_employee_view;

    --%test(has_permission returns FALSE for low-grade PAYROLL EDIT)
    PROCEDURE test_perm_low_grade_denied;

    --%test(has_permission returns FALSE for non-existent employee)
    PROCEDURE test_perm_nonexistent_emp;

    -- -------------------------------------------------------------------
    -- encrypt_ssn / decrypt_ssn Tests
    -- -------------------------------------------------------------------
    --%test(encrypt_ssn returns non-null encrypted value)
    PROCEDURE test_encrypt_ssn_basic;

    --%test(encrypt_ssn produces different output than input)
    PROCEDURE test_encrypt_ssn_different;

    --%test(decrypt_ssn recovers original SSN)
    PROCEDURE test_decrypt_ssn_roundtrip;

    --%test(decrypt_ssn returns error marker for invalid input)
    PROCEDURE test_decrypt_ssn_invalid;

    --%test(encrypt_ssn produces consistent output for same input)
    PROCEDURE test_encrypt_ssn_consistent;

    -- -------------------------------------------------------------------
    -- change_password Tests
    -- -------------------------------------------------------------------
    --%test(change_password succeeds for valid password meeting all criteria)
    PROCEDURE test_change_pwd_valid;

    --%test(change_password raises -20310 for password shorter than 8 chars)
    PROCEDURE test_change_pwd_too_short;

    --%test(change_password raises -20311 for missing uppercase letter)
    PROCEDURE test_change_pwd_no_upper;

    --%test(change_password raises -20312 for missing number)
    PROCEDURE test_change_pwd_no_number;

END UT_PKG_SECURITY;
/
