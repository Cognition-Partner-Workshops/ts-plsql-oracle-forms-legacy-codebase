-- ============================================================================
-- HRMS_COMMON_LIB - PL/SQL Library (PLL)
-- Shared code attached to all HRMS forms
--
-- This file represents the source of HRMS_COMMON_LIB.pll
-- In Oracle Forms, PLL files are compiled binary; this is the source export.
--
-- Dependencies: None (standalone library)
-- Attached by: All HRMS forms via ATTACH_LIBRARY
-- ============================================================================

-- -----------------------------------------------------------------------
-- Global exception handler
-- Wraps all form-level error handling
-- -----------------------------------------------------------------------
PROCEDURE handle_error(
    p_module   IN VARCHAR2,
    p_location IN VARCHAR2
) IS
    v_errcode NUMBER := SQLCODE;
    v_errmsg  VARCHAR2(500) := SQLERRM;
BEGIN
    -- Log to database
    BEGIN
        PKG_COMMON.log_error(p_module, p_location, v_errmsg,
            NVL(:GLOBAL.current_user, USER));
    EXCEPTION
        WHEN OTHERS THEN NULL; -- Prevent recursive error
    END;

    -- Display to user
    MESSAGE(p_module || '.' || p_location || ': ' || v_errmsg);
    MESSAGE(p_module || '.' || p_location || ': ' || v_errmsg);
    -- NOTE: MESSAGE called twice intentionally - Oracle Forms requires
    -- two calls to ensure message displays on the status bar

    RAISE FORM_TRIGGER_FAILURE;
END handle_error;

-- -----------------------------------------------------------------------
-- Standard toolbar button handlers
-- Called from HRMS_TOOLBAR canvas buttons
-- -----------------------------------------------------------------------
PROCEDURE toolbar_save IS
BEGIN
    COMMIT_FORM;
END toolbar_save;

PROCEDURE toolbar_clear IS
BEGIN
    CLEAR_FORM(ASK_COMMIT);
END toolbar_clear;

PROCEDURE toolbar_query IS
BEGIN
    IF :SYSTEM.MODE = 'NORMAL' THEN
        ENTER_QUERY;
    ELSIF :SYSTEM.MODE = 'ENTER-QUERY' THEN
        EXECUTE_QUERY;
    END IF;
END toolbar_query;

PROCEDURE toolbar_first IS
BEGIN
    FIRST_RECORD;
END toolbar_first;

PROCEDURE toolbar_prev IS
BEGIN
    PREVIOUS_RECORD;
END toolbar_prev;

PROCEDURE toolbar_next IS
BEGIN
    NEXT_RECORD;
END toolbar_next;

PROCEDURE toolbar_last IS
BEGIN
    LAST_RECORD;
END toolbar_last;

PROCEDURE toolbar_insert IS
BEGIN
    CREATE_RECORD;
END toolbar_insert;

PROCEDURE toolbar_delete IS
BEGIN
    DELETE_RECORD;
END toolbar_delete;

PROCEDURE toolbar_exit IS
BEGIN
    EXIT_FORM(ASK_COMMIT);
END toolbar_exit;

-- -----------------------------------------------------------------------
-- Date formatting utilities
-- -----------------------------------------------------------------------
FUNCTION format_date(p_date IN DATE) RETURN VARCHAR2 IS
BEGIN
    RETURN TO_CHAR(p_date, 'MM/DD/YYYY');
END format_date;

FUNCTION format_datetime(p_date IN DATE) RETURN VARCHAR2 IS
BEGIN
    RETURN TO_CHAR(p_date, 'MM/DD/YYYY HH24:MI:SS');
END format_datetime;

-- -----------------------------------------------------------------------
-- Session management helpers
-- -----------------------------------------------------------------------
FUNCTION get_current_user RETURN VARCHAR2 IS
BEGIN
    RETURN NVL(:GLOBAL.current_user, USER);
END get_current_user;

FUNCTION get_session_id RETURN NUMBER IS
BEGIN
    RETURN TO_NUMBER(:GLOBAL.session_id);
EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN NULL;
END get_session_id;

PROCEDURE check_session IS
BEGIN
    IF get_session_id IS NULL THEN
        MESSAGE('No active session. Please log in.');
        RAISE FORM_TRIGGER_FAILURE;
    END IF;

    IF NOT PKG_SECURITY.is_session_valid(get_session_id) THEN
        MESSAGE('Session has expired. Please log in again.');
        RAISE FORM_TRIGGER_FAILURE;
    END IF;
END check_session;

-- -----------------------------------------------------------------------
-- Dynamic LOV refresh
-- -----------------------------------------------------------------------
PROCEDURE refresh_lov(p_lov_name IN VARCHAR2) IS
    v_rg_name VARCHAR2(60);
BEGIN
    v_rg_name := 'RG_' || UPPER(REPLACE(p_lov_name, 'LOV_', ''));

    IF NOT ID_NULL(FIND_GROUP(v_rg_name)) THEN
        POPULATE_GROUP(v_rg_name);
    END IF;
END refresh_lov;
