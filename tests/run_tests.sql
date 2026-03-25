-- ============================================================================
-- utPLSQL Test Runner Script
-- Runs all HRMS unit tests with coverage reporting
-- ============================================================================
-- Usage: @run_tests.sql
-- Prerequisites: utPLSQL v3 installed in the database
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 999

PROMPT ============================================================
PROMPT  HRMS utPLSQL Test Suite - Running All Tests
PROMPT ============================================================

-- Compile all test package specifications first
PROMPT Compiling test package specifications...
@@packages/UT_PKG_COMMON.pks
@@packages/UT_PKG_AUDIT.pks
@@packages/UT_PKG_VALIDATION.pks
@@packages/UT_PKG_NOTIFICATION.pks
@@packages/UT_PKG_SECURITY.pks
@@packages/UT_PKG_EMPLOYEE.pks
@@packages/UT_PKG_PAYROLL.pks
@@packages/UT_PKG_LEAVE.pks
@@packages/UT_PKG_PERFORMANCE.pks
@@packages/UT_PKG_REPORTING.pks
@@packages/UT_PKG_INTEGRATION.pks
@@packages/UT_TRG_EMPLOYEES.pks
@@packages/UT_TRG_AUDIT.pks

-- Compile all test package bodies
PROMPT Compiling test package bodies...
@@packages/UT_PKG_COMMON.pkb
@@packages/UT_PKG_AUDIT.pkb
@@packages/UT_PKG_VALIDATION.pkb
@@packages/UT_PKG_NOTIFICATION.pkb
@@packages/UT_PKG_SECURITY.pkb
@@packages/UT_PKG_EMPLOYEE.pkb
@@packages/UT_PKG_PAYROLL.pkb
@@packages/UT_PKG_LEAVE.pkb
@@packages/UT_PKG_PERFORMANCE.pkb
@@packages/UT_PKG_REPORTING.pkb
@@packages/UT_PKG_INTEGRATION.pkb
@@packages/UT_TRG_EMPLOYEES.pkb
@@packages/UT_TRG_AUDIT.pkb

PROMPT
PROMPT ============================================================
PROMPT  Running utPLSQL tests with coverage...
PROMPT ============================================================

-- Run all tests in the HRMS suite path with coverage
BEGIN
    ut.run(
        a_path => 'hrms',
        a_reporter => ut_documentation_reporter(),
        a_coverage_schemes => ut_varchar2_list('HRMS'),
        a_source_files => ut_varchar2_list(
            'plsql/packages/PKG_COMMON.pkb',
            'plsql/packages/PKG_AUDIT.pkb',
            'plsql/packages/PKG_VALIDATION.pkb',
            'plsql/packages/PKG_NOTIFICATION.pkb',
            'plsql/packages/PKG_SECURITY.pkb',
            'plsql/packages/PKG_EMPLOYEE.pkb',
            'plsql/packages/PKG_PAYROLL.pkb',
            'plsql/packages/PKG_LEAVE.pkb',
            'plsql/packages/PKG_PERFORMANCE.pkb',
            'plsql/packages/PKG_REPORTING.pkb',
            'plsql/packages/PKG_INTEGRATION.pkb'
        ),
        a_test_files => ut_varchar2_list(
            'tests/packages/UT_PKG_COMMON.pkb',
            'tests/packages/UT_PKG_AUDIT.pkb',
            'tests/packages/UT_PKG_VALIDATION.pkb',
            'tests/packages/UT_PKG_NOTIFICATION.pkb',
            'tests/packages/UT_PKG_SECURITY.pkb',
            'tests/packages/UT_PKG_EMPLOYEE.pkb',
            'tests/packages/UT_PKG_PAYROLL.pkb',
            'tests/packages/UT_PKG_LEAVE.pkb',
            'tests/packages/UT_PKG_PERFORMANCE.pkb',
            'tests/packages/UT_PKG_REPORTING.pkb',
            'tests/packages/UT_PKG_INTEGRATION.pkb',
            'tests/packages/UT_TRG_EMPLOYEES.pkb',
            'tests/packages/UT_TRG_AUDIT.pkb'
        )
    );
END;
/

PROMPT
PROMPT ============================================================
PROMPT  Test execution complete.
PROMPT ============================================================
