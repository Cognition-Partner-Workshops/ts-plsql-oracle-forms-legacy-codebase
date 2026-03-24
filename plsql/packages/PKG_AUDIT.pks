CREATE OR REPLACE PACKAGE HRMS.PKG_AUDIT AS
-- ============================================================================
-- PKG_AUDIT - Audit Trail Package
-- Centralized audit logging for all DML operations
--
-- Dependencies: None (base package)
-- Called by: All other packages, database triggers
-- ============================================================================

    PROCEDURE log_action(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_action     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER,
        p_old_values IN CLOB DEFAULT NULL,
        p_new_values IN CLOB DEFAULT NULL
    );

    PROCEDURE purge_old_records(
        p_days_to_keep IN NUMBER DEFAULT 365,
        p_user         IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_change_history(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_from_date  IN DATE DEFAULT NULL,
        p_to_date    IN DATE DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END PKG_AUDIT;
/
