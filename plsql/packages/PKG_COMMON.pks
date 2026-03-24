CREATE OR REPLACE PACKAGE HRMS.PKG_COMMON AS
-- ============================================================================
-- PKG_COMMON - Shared Utility Package
-- Logging, date utilities, formatting, configuration parameter access
--
-- Dependencies: None (base package - no cross-package dependencies)
-- Called by: All other packages, all forms
-- ============================================================================

    -- Error log table type
    TYPE t_error_rec IS RECORD (
        error_id    NUMBER,
        package_name VARCHAR2(60),
        procedure_name VARCHAR2(60),
        error_message VARCHAR2(4000),
        error_date  DATE,
        username    VARCHAR2(30)
    );

    -- -----------------------------------------------------------------------
    -- Logging
    -- -----------------------------------------------------------------------
    PROCEDURE log_error(
        p_package   IN VARCHAR2,
        p_procedure IN VARCHAR2,
        p_message   IN VARCHAR2,
        p_user      IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE log_info(
        p_package   IN VARCHAR2,
        p_procedure IN VARCHAR2,
        p_message   IN VARCHAR2,
        p_user      IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Configuration
    -- -----------------------------------------------------------------------
    FUNCTION get_param(
        p_group IN VARCHAR2,
        p_code  IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION get_param_number(
        p_group IN VARCHAR2,
        p_code  IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION get_param_date(
        p_group IN VARCHAR2,
        p_code  IN VARCHAR2
    ) RETURN DATE;

    PROCEDURE set_param(
        p_group IN VARCHAR2,
        p_code  IN VARCHAR2,
        p_value IN VARCHAR2,
        p_user  IN VARCHAR2 DEFAULT USER
    );

    -- -----------------------------------------------------------------------
    -- Date Utilities
    -- -----------------------------------------------------------------------
    FUNCTION business_days_between(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN NUMBER;

    FUNCTION add_business_days(
        p_date IN DATE,
        p_days IN NUMBER
    ) RETURN DATE;

    FUNCTION get_fiscal_year(
        p_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER;

    FUNCTION get_fiscal_quarter(
        p_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER;

    -- -----------------------------------------------------------------------
    -- Formatting
    -- -----------------------------------------------------------------------
    FUNCTION format_phone(
        p_phone IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION format_ssn_masked(
        p_ssn IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION format_currency(
        p_amount        IN NUMBER,
        p_currency_code IN VARCHAR2 DEFAULT 'USD'
    ) RETURN VARCHAR2;

    FUNCTION format_name(
        p_first_name IN VARCHAR2,
        p_last_name  IN VARCHAR2,
        p_format     IN VARCHAR2 DEFAULT 'FL'  -- FL=First Last, LF=Last, First
    ) RETURN VARCHAR2;

    -- -----------------------------------------------------------------------
    -- Validation
    -- -----------------------------------------------------------------------
    FUNCTION is_valid_email(
        p_email IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION is_valid_phone(
        p_phone IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION is_valid_ssn(
        p_ssn IN VARCHAR2
    ) RETURN BOOLEAN;

END PKG_COMMON;
/
