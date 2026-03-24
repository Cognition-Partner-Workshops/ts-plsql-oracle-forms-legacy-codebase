-- ============================================================================
-- Generic Audit Triggers
-- Applied to key tables for change tracking
-- ============================================================================

-- -----------------------------------------------------------------------
-- TRG_SALARY_AUDIT
-- Tracks all salary record changes for compliance
-- -----------------------------------------------------------------------
CREATE OR REPLACE TRIGGER HRMS.TRG_SALARY_AUDIT
AFTER INSERT OR UPDATE OR DELETE ON HRMS.SALARY_RECORDS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
    v_old_json CLOB;
    v_new_json CLOB;
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        v_new_json := '{"emp_id":' || :NEW.EMP_ID ||
                      ',"salary":' || :NEW.BASE_SALARY ||
                      ',"effective":"' || TO_CHAR(:NEW.EFFECTIVE_DATE, 'YYYY-MM-DD') || '"}';
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_old_json := '{"salary":' || :OLD.BASE_SALARY || ',"active":"' || :OLD.ACTIVE_FLAG || '"}';
        v_new_json := '{"salary":' || :NEW.BASE_SALARY || ',"active":"' || :NEW.ACTIVE_FLAG || '"}';
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_old_json := '{"emp_id":' || :OLD.EMP_ID || ',"salary":' || :OLD.BASE_SALARY || '}';
    END IF;

    PKG_AUDIT.log_action(
        'SALARY_RECORDS',
        NVL(:NEW.SALARY_ID, :OLD.SALARY_ID),
        v_action,
        NVL(:NEW.MODIFIED_BY, USER),
        v_old_json,
        v_new_json
    );
END TRG_SALARY_AUDIT;
/

-- -----------------------------------------------------------------------
-- TRG_LEAVE_REQUEST_AUDIT
-- Tracks leave request status changes
-- -----------------------------------------------------------------------
CREATE OR REPLACE TRIGGER HRMS.TRG_LEAVE_REQUEST_AUDIT
AFTER UPDATE OF STATUS ON HRMS.LEAVE_REQUESTS
FOR EACH ROW
BEGIN
    PKG_AUDIT.log_action(
        'LEAVE_REQUESTS',
        :NEW.REQUEST_ID,
        'STATUS_CHANGE',
        NVL(:NEW.MODIFIED_BY, USER),
        '{"status":"' || :OLD.STATUS || '"}',
        '{"status":"' || :NEW.STATUS || '"}'
    );
END TRG_LEAVE_REQUEST_AUDIT;
/

-- -----------------------------------------------------------------------
-- TRG_DEPARTMENT_AUDIT
-- Tracks department structure changes
-- -----------------------------------------------------------------------
CREATE OR REPLACE TRIGGER HRMS.TRG_DEPARTMENT_AUDIT
AFTER INSERT OR UPDATE OR DELETE ON HRMS.DEPARTMENTS
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_action := 'INSERT';
    ELSIF UPDATING THEN v_action := 'UPDATE';
    ELSIF DELETING THEN v_action := 'DELETE';
    END IF;

    PKG_AUDIT.log_action(
        'DEPARTMENTS',
        NVL(:NEW.DEPT_ID, :OLD.DEPT_ID),
        v_action,
        USER
    );
END TRG_DEPARTMENT_AUDIT;
/
