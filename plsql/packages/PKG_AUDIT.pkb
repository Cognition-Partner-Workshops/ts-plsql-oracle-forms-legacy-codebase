CREATE OR REPLACE PACKAGE BODY HRMS.PKG_AUDIT AS
-- ============================================================================
-- PKG_AUDIT - Audit Trail Package Body
-- ============================================================================

    PROCEDURE log_action(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_action     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER,
        p_old_values IN CLOB DEFAULT NULL,
        p_new_values IN CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO AUDIT_LOG (
            AUDIT_ID, TABLE_NAME, RECORD_ID, ACTION_TYPE,
            OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_DATE,
            IP_ADDRESS, SESSION_ID
        ) VALUES (
            SEQ_AUDIT.NEXTVAL, p_table_name, p_record_id, p_action,
            p_old_values, p_new_values, p_user, SYSDATE,
            SYS_CONTEXT('USERENV', 'IP_ADDRESS'),
            SYS_CONTEXT('USERENV', 'SESSIONID')
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Audit logging must never fail the calling transaction
            ROLLBACK;
    END log_action;

    PROCEDURE purge_old_records(
        p_days_to_keep IN NUMBER DEFAULT 365,
        p_user         IN VARCHAR2 DEFAULT USER
    ) IS
        v_deleted NUMBER;
    BEGIN
        DELETE FROM AUDIT_LOG
        WHERE CHANGED_DATE < SYSDATE - p_days_to_keep;

        v_deleted := SQL%ROWCOUNT;
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Purged ' || v_deleted || ' audit records older than ' ||
            p_days_to_keep || ' days');
    END purge_old_records;

    FUNCTION get_change_history(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_from_date  IN DATE DEFAULT NULL,
        p_to_date    IN DATE DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT AUDIT_ID, TABLE_NAME, RECORD_ID, ACTION_TYPE,
                   OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_DATE,
                   IP_ADDRESS
            FROM AUDIT_LOG
            WHERE TABLE_NAME = p_table_name
            AND RECORD_ID = p_record_id
            AND (p_from_date IS NULL OR CHANGED_DATE >= p_from_date)
            AND (p_to_date IS NULL OR CHANGED_DATE <= p_to_date)
            ORDER BY CHANGED_DATE DESC;

        RETURN v_cursor;
    END get_change_history;

END PKG_AUDIT;
/
