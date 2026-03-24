CREATE OR REPLACE PACKAGE HRMS.PKG_SECURITY AS
-- ============================================================================
-- PKG_SECURITY - Authentication & Authorization Package
-- Login, session management, role-based access, encryption
--
-- Dependencies: PKG_COMMON, PKG_AUDIT
-- Called by: HRMS_LOGIN form, all forms (session validation)
-- Known issues:
--   - Password stored as MD5 hash (should be bcrypt/scrypt)
--   - Session timeout check uses DB server time, not app server time
--   - No account lockout after failed attempts
--   - DBMS_CRYPTO key hard-coded in package body
-- ============================================================================

    e_invalid_credentials EXCEPTION;
    e_account_locked      EXCEPTION;
    e_session_expired     EXCEPTION;
    e_insufficient_priv   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_credentials, -20301);
    PRAGMA EXCEPTION_INIT(e_account_locked,      -20302);
    PRAGMA EXCEPTION_INIT(e_session_expired,     -20303);
    PRAGMA EXCEPTION_INIT(e_insufficient_priv,   -20304);

    FUNCTION authenticate(
        p_username IN VARCHAR2,
        p_password IN VARCHAR2,
        p_ip_address IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE logout(
        p_session_id IN NUMBER
    );

    FUNCTION is_session_valid(
        p_session_id IN NUMBER
    ) RETURN BOOLEAN;

    FUNCTION has_permission(
        p_emp_id     IN NUMBER,
        p_module     IN VARCHAR2,
        p_action     IN VARCHAR2 DEFAULT 'VIEW'
    ) RETURN BOOLEAN;

    FUNCTION encrypt_ssn(
        p_ssn IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION decrypt_ssn(
        p_encrypted IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION hash_password(
        p_password IN VARCHAR2
    ) RETURN VARCHAR2;

    PROCEDURE change_password(
        p_emp_id       IN NUMBER,
        p_old_password IN VARCHAR2,
        p_new_password IN VARCHAR2
    );

END PKG_SECURITY;
/
