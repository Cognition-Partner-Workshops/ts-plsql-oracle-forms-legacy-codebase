CREATE OR REPLACE PACKAGE HRMS.UT_PKG_INTEGRATION AS
-- ============================================================================
-- UT_PKG_INTEGRATION - Unit Tests for PKG_INTEGRATION
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_INTEGRATION body
-- ============================================================================

    --%suite(PKG_INTEGRATION - External System Integration Package)
    --%suitepath(hrms.integration)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    --%test(generate_gl_journal processes payroll run for GL posting)
    PROCEDURE test_gl_journal_basic;

    --%test(generate_gl_journal raises error for non-existent run)
    PROCEDURE test_gl_journal_bad_run;

    --%test(generate_gl_journal handles run with no details)
    PROCEDURE test_gl_journal_empty_run;

    --%test(export_benefits_feed generates ADP-format feed file)
    PROCEDURE test_benefits_feed_basic;

    --%test(export_benefits_feed handles custom effective date)
    PROCEDURE test_benefits_feed_date;

    --%test(import_time_attendance validates file name)
    PROCEDURE test_time_import_bad_file;

    --%test(import_time_attendance handles missing file gracefully)
    PROCEDURE test_time_import_missing;

    --%test(sync_org_structure completes without error)
    PROCEDURE test_sync_org_basic;

    --%test(get_integration_status returns status for known integration)
    PROCEDURE test_get_status_known;

    --%test(get_integration_status returns NULL for unknown integration)
    PROCEDURE test_get_status_unknown;

END UT_PKG_INTEGRATION;
/
