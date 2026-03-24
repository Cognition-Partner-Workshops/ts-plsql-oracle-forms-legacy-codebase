CREATE OR REPLACE PACKAGE HRMS.PKG_INTEGRATION AS
-- ============================================================================
-- PKG_INTEGRATION - External System Integration Package
-- GL posting, benefits provider feed, time & attendance import
--
-- Dependencies: PKG_COMMON, PKG_PAYROLL, PKG_EMPLOYEE
-- Called by: Batch scheduler (nightly GL feed, weekly benefits sync)
-- Known issues:
--   - GL posting uses flat file exchange (UTL_FILE) instead of API
--   - Benefits feed format is vendor-specific (ADP format)
--   - No retry logic for failed file transfers
--   - FTP credentials stored in SYSTEM_PARAMETERS table (cleartext)
-- ============================================================================

    TYPE t_gl_entry IS RECORD (
        journal_date    DATE,
        account_code    VARCHAR2(30),
        debit_amount    NUMBER(15,2),
        credit_amount   NUMBER(15,2),
        description     VARCHAR2(200),
        reference       VARCHAR2(100)
    );

    TYPE t_gl_entry_table IS TABLE OF t_gl_entry INDEX BY BINARY_INTEGER;

    PROCEDURE generate_gl_journal(
        p_run_id IN NUMBER,
        p_user   IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE export_benefits_feed(
        p_effective_date IN DATE DEFAULT SYSDATE,
        p_user           IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE import_time_attendance(
        p_file_name IN VARCHAR2,
        p_user      IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE sync_org_structure(
        p_user IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_integration_status(
        p_integration_name IN VARCHAR2
    ) RETURN VARCHAR2;

END PKG_INTEGRATION;
/
