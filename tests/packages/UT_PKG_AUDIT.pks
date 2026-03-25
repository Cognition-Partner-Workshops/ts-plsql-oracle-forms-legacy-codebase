CREATE OR REPLACE PACKAGE HRMS.UT_PKG_AUDIT AS
-- ============================================================================
-- UT_PKG_AUDIT - Unit Tests for PKG_AUDIT
-- Framework: utPLSQL v3
-- Coverage target: >85% of PKG_AUDIT body
-- ============================================================================

    --%suite(PKG_AUDIT - Audit Trail Package)
    --%suitepath(hrms.audit)

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- log_action Tests
    -- -------------------------------------------------------------------
    --%test(log_action inserts audit record with all parameters)
    PROCEDURE test_log_action_full;

    --%test(log_action works with minimal parameters)
    PROCEDURE test_log_action_minimal;

    --%test(log_action uses autonomous transaction - survives rollback)
    PROCEDURE test_log_action_autonomous;

    --%test(log_action captures IP address from session context)
    PROCEDURE test_log_action_ip_address;

    --%test(log_action silently handles insert failure)
    PROCEDURE test_log_action_silent_failure;

    --%test(log_action records INSERT action correctly)
    PROCEDURE test_log_action_insert;

    --%test(log_action records UPDATE action correctly)
    PROCEDURE test_log_action_update;

    --%test(log_action records DELETE action correctly)
    PROCEDURE test_log_action_delete;

    -- -------------------------------------------------------------------
    -- purge_old_records Tests
    -- -------------------------------------------------------------------
    --%test(purge_old_records deletes records older than specified days)
    PROCEDURE test_purge_old_records;

    --%test(purge_old_records with default 365 days)
    PROCEDURE test_purge_default_days;

    --%test(purge_old_records does not delete recent records)
    PROCEDURE test_purge_keeps_recent;

    -- -------------------------------------------------------------------
    -- get_change_history Tests
    -- -------------------------------------------------------------------
    --%test(get_change_history returns cursor with matching records)
    PROCEDURE test_get_history_basic;

    --%test(get_change_history filters by date range)
    PROCEDURE test_get_history_date_range;

    --%test(get_change_history returns empty cursor for non-existent record)
    PROCEDURE test_get_history_no_data;

    --%test(get_change_history with NULL date filters returns all records)
    PROCEDURE test_get_history_null_dates;

    --%test(get_change_history orders by date descending)
    PROCEDURE test_get_history_order;

END UT_PKG_AUDIT;
/
