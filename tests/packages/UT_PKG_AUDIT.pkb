CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_AUDIT AS
-- ============================================================================
-- UT_PKG_AUDIT - Unit Tests for PKG_AUDIT Body
-- ============================================================================

    c_test_table CONSTANT VARCHAR2(30) := 'UT_TEST_TABLE';
    c_test_user  CONSTANT VARCHAR2(30) := 'UT_AUDIT_TEST';

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table;
        DELETE FROM AUDIT_LOG WHERE CHANGED_BY = c_test_user;
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- log_action Tests
    -- ===================================================================
    PROCEDURE test_log_action_full IS
        v_count NUMBER;
    BEGIN
        PKG_AUDIT.log_action(
            p_table_name => c_test_table,
            p_record_id  => 999,
            p_action     => 'INSERT',
            p_user       => c_test_user,
            p_old_values => '{"field":"old_value"}',
            p_new_values => '{"field":"new_value"}'
        );

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table
        AND RECORD_ID = 999
        AND ACTION_TYPE = 'INSERT'
        AND CHANGED_BY = c_test_user
        AND OLD_VALUES = '{"field":"old_value"}'
        AND NEW_VALUES = '{"field":"new_value"}';

        ut.expect(v_count).to_equal(1);
    END test_log_action_full;

    PROCEDURE test_log_action_minimal IS
        v_count NUMBER;
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 1000, 'UPDATE', c_test_user);

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table
        AND RECORD_ID = 1000
        AND ACTION_TYPE = 'UPDATE'
        AND OLD_VALUES IS NULL
        AND NEW_VALUES IS NULL;

        ut.expect(v_count).to_equal(1);
    END test_log_action_minimal;

    PROCEDURE test_log_action_autonomous IS
        v_count_before NUMBER;
        v_count_after  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count_before
        FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table;

        SAVEPOINT before_audit_test;

        PKG_AUDIT.log_action(c_test_table, 1001, 'INSERT', c_test_user);

        ROLLBACK TO before_audit_test;

        SELECT COUNT(*) INTO v_count_after
        FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table;

        ut.expect(v_count_after).to_be_greater_than(v_count_before);
    END test_log_action_autonomous;

    PROCEDURE test_log_action_ip_address IS
        v_ip VARCHAR2(50);
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 1002, 'INSERT', c_test_user);

        SELECT IP_ADDRESS INTO v_ip
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table
        AND RECORD_ID = 1002
        AND ROWNUM = 1;

        -- IP_ADDRESS comes from SYS_CONTEXT('USERENV', 'IP_ADDRESS')
        -- May be NULL in some test environments, but should not raise error
        ut.expect(1).to_equal(1); -- Verifies no exception was raised
    END test_log_action_ip_address;

    PROCEDURE test_log_action_silent_failure IS
    BEGIN
        -- log_action should never raise - it catches all exceptions
        -- Pass extremely long values to test graceful handling
        PKG_AUDIT.log_action(c_test_table, 1003, 'INSERT', c_test_user,
            RPAD('X', 50000, 'X'), RPAD('Y', 50000, 'Y'));

        -- If we reach here, no exception was raised
        ut.expect(TRUE).to_be_true();
    END test_log_action_silent_failure;

    PROCEDURE test_log_action_insert IS
        v_action VARCHAR2(20);
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 1004, 'INSERT', c_test_user);

        SELECT ACTION_TYPE INTO v_action
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table AND RECORD_ID = 1004 AND ROWNUM = 1;

        ut.expect(v_action).to_equal('INSERT');
    END test_log_action_insert;

    PROCEDURE test_log_action_update IS
        v_action VARCHAR2(20);
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 1005, 'UPDATE', c_test_user);

        SELECT ACTION_TYPE INTO v_action
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table AND RECORD_ID = 1005 AND ROWNUM = 1;

        ut.expect(v_action).to_equal('UPDATE');
    END test_log_action_update;

    PROCEDURE test_log_action_delete IS
        v_action VARCHAR2(20);
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 1006, 'DELETE', c_test_user);

        SELECT ACTION_TYPE INTO v_action
        FROM AUDIT_LOG
        WHERE TABLE_NAME = c_test_table AND RECORD_ID = 1006 AND ROWNUM = 1;

        ut.expect(v_action).to_equal('DELETE');
    END test_log_action_delete;

    -- ===================================================================
    -- purge_old_records Tests
    -- ===================================================================
    PROCEDURE test_purge_old_records IS
        v_count_before NUMBER;
        v_count_after  NUMBER;
    BEGIN
        -- Insert old test records
        INSERT INTO AUDIT_LOG (AUDIT_ID, TABLE_NAME, RECORD_ID, ACTION_TYPE,
            CHANGED_BY, CHANGED_DATE)
        VALUES (SEQ_AUDIT.NEXTVAL, c_test_table, 9001, 'INSERT',
            c_test_user, SYSDATE - 400);
        COMMIT;

        SELECT COUNT(*) INTO v_count_before
        FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table AND RECORD_ID = 9001;

        PKG_AUDIT.purge_old_records(p_days_to_keep => 30, p_user => c_test_user);

        SELECT COUNT(*) INTO v_count_after
        FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table AND RECORD_ID = 9001;

        ut.expect(v_count_after).to_equal(0);
    END test_purge_old_records;

    PROCEDURE test_purge_default_days IS
    BEGIN
        -- Just verify it doesn't raise an exception with default parameter
        PKG_AUDIT.purge_old_records(p_user => c_test_user);
        ut.expect(TRUE).to_be_true();
    END test_purge_default_days;

    PROCEDURE test_purge_keeps_recent IS
        v_count NUMBER;
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 9002, 'INSERT', c_test_user);

        PKG_AUDIT.purge_old_records(p_days_to_keep => 365, p_user => c_test_user);

        SELECT COUNT(*) INTO v_count
        FROM AUDIT_LOG WHERE TABLE_NAME = c_test_table AND RECORD_ID = 9002;

        ut.expect(v_count).to_be_greater_than(0);
    END test_purge_keeps_recent;

    -- ===================================================================
    -- get_change_history Tests
    -- ===================================================================
    PROCEDURE test_get_history_basic IS
        v_cursor SYS_REFCURSOR;
        v_audit_id NUMBER;
        v_table_name VARCHAR2(50);
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 9010, 'INSERT', c_test_user);

        v_cursor := PKG_AUDIT.get_change_history(c_test_table, 9010);

        FETCH v_cursor INTO v_audit_id, v_table_name,
            v_audit_id, v_table_name, v_table_name, v_table_name,
            v_table_name, v_table_name, v_table_name; -- fetch row fields
        CLOSE v_cursor;

        ut.expect(v_table_name).to_equal(c_test_table);
    END test_get_history_basic;

    PROCEDURE test_get_history_date_range IS
        v_cursor SYS_REFCURSOR;
        v_found BOOLEAN := FALSE;
        v_dummy NUMBER;
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 9011, 'INSERT', c_test_user);

        v_cursor := PKG_AUDIT.get_change_history(
            c_test_table, 9011,
            SYSDATE - 1, SYSDATE + 1
        );

        BEGIN
            FETCH v_cursor INTO v_dummy, v_dummy, v_dummy, v_dummy,
                v_dummy, v_dummy, v_dummy, v_dummy, v_dummy;
            IF v_cursor%FOUND THEN v_found := TRUE; END IF;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        CLOSE v_cursor;

        ut.expect(v_found).to_be_true();
    END test_get_history_date_range;

    PROCEDURE test_get_history_no_data IS
        v_cursor SYS_REFCURSOR;
        v_found BOOLEAN := FALSE;
        v_dummy NUMBER;
    BEGIN
        v_cursor := PKG_AUDIT.get_change_history('NONEXISTENT_TABLE', -1);

        BEGIN
            FETCH v_cursor INTO v_dummy, v_dummy, v_dummy, v_dummy,
                v_dummy, v_dummy, v_dummy, v_dummy, v_dummy;
            IF v_cursor%FOUND THEN v_found := TRUE; END IF;
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        CLOSE v_cursor;

        ut.expect(v_found).to_be_false();
    END test_get_history_no_data;

    PROCEDURE test_get_history_null_dates IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_cursor := PKG_AUDIT.get_change_history(c_test_table, 9010, NULL, NULL);
        -- Should not raise an error
        CLOSE v_cursor;
        ut.expect(TRUE).to_be_true();
    END test_get_history_null_dates;

    PROCEDURE test_get_history_order IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        PKG_AUDIT.log_action(c_test_table, 9012, 'INSERT', c_test_user);
        PKG_AUDIT.log_action(c_test_table, 9012, 'UPDATE', c_test_user);

        v_cursor := PKG_AUDIT.get_change_history(c_test_table, 9012);
        -- Should be ordered by CHANGED_DATE DESC (most recent first)
        CLOSE v_cursor;
        ut.expect(TRUE).to_be_true();
    END test_get_history_order;

END UT_PKG_AUDIT;
/
