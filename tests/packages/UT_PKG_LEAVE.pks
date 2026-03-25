CREATE OR REPLACE PACKAGE HRMS.UT_PKG_LEAVE AS
-- ============================================================================
-- UT_PKG_LEAVE - Unit Tests for PKG_LEAVE
-- Framework: utPLSQL v3
-- Coverage target: >80% of PKG_LEAVE body
-- ============================================================================

    --%suite(PKG_LEAVE - Leave Management Package)
    --%suitepath(hrms.leave)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- calculate_business_days Tests
    -- -------------------------------------------------------------------
    --%test(calculate_business_days counts only weekdays)
    PROCEDURE test_biz_days_weekdays;

    --%test(calculate_business_days excludes weekends)
    PROCEDURE test_biz_days_weekend;

    --%test(calculate_business_days excludes holidays)
    PROCEDURE test_biz_days_holidays;

    --%test(calculate_business_days handles same-day range)
    PROCEDURE test_biz_days_same_day;

    -- -------------------------------------------------------------------
    -- submit_leave_request Tests
    -- -------------------------------------------------------------------
    --%test(submit_leave_request creates pending request)
    PROCEDURE test_submit_basic;

    --%test(submit_leave_request validates employee is active)
    PROCEDURE test_submit_inactive_emp;

    --%test(submit_leave_request validates leave type exists)
    PROCEDURE test_submit_bad_type;

    --%test(submit_leave_request validates date range)
    PROCEDURE test_submit_bad_dates;

    --%test(submit_leave_request detects overlapping requests)
    PROCEDURE test_submit_overlap;

    --%test(submit_leave_request checks balance for accrual types)
    PROCEDURE test_submit_insufficient_balance;

    --%test(submit_leave_request handles half-day request)
    PROCEDURE test_submit_half_day;

    --%test(submit_leave_request rejects far backdated requests)
    PROCEDURE test_submit_backdated;

    --%test(submit_leave_request auto-approves when no approval required)
    PROCEDURE test_submit_auto_approve;

    --%test(submit_leave_request sends notification to manager)
    PROCEDURE test_submit_notifies_manager;

    -- -------------------------------------------------------------------
    -- approve_leave_request Tests
    -- -------------------------------------------------------------------
    --%test(approve_leave_request sets status to APPROVED)
    PROCEDURE test_approve_basic;

    --%test(approve_leave_request raises error for non-PENDING status)
    PROCEDURE test_approve_wrong_status;

    --%test(approve_leave_request updates balance from pending to used)
    PROCEDURE test_approve_updates_balance;

    -- -------------------------------------------------------------------
    -- reject_leave_request Tests
    -- -------------------------------------------------------------------
    --%test(reject_leave_request sets status to REJECTED)
    PROCEDURE test_reject_basic;

    --%test(reject_leave_request releases pending balance)
    PROCEDURE test_reject_releases_balance;

    --%test(reject_leave_request raises error for non-PENDING status)
    PROCEDURE test_reject_wrong_status;

    -- -------------------------------------------------------------------
    -- cancel_leave_request Tests
    -- -------------------------------------------------------------------
    --%test(cancel_leave_request cancels PENDING request)
    PROCEDURE test_cancel_pending;

    --%test(cancel_leave_request cancels APPROVED request and restores used)
    PROCEDURE test_cancel_approved;

    --%test(cancel_leave_request raises error for REJECTED status)
    PROCEDURE test_cancel_wrong_status;

    -- -------------------------------------------------------------------
    -- get_leave_balance Tests
    -- -------------------------------------------------------------------
    --%test(get_leave_balance returns calculated balance)
    PROCEDURE test_balance_basic;

    --%test(get_leave_balance returns 0 for no record)
    PROCEDURE test_balance_no_record;

    -- -------------------------------------------------------------------
    -- adjust_leave_balance Tests
    -- -------------------------------------------------------------------
    --%test(adjust_leave_balance adds adjustment amount)
    PROCEDURE test_adjust_basic;

    --%test(adjust_leave_balance initializes balance if not found)
    PROCEDURE test_adjust_initializes;

    -- -------------------------------------------------------------------
    -- initialize_balances Tests
    -- -------------------------------------------------------------------
    --%test(initialize_balances creates records for all leave types)
    PROCEDURE test_init_balances;

    --%test(initialize_balances skips existing records)
    PROCEDURE test_init_balances_no_dup;

    -- -------------------------------------------------------------------
    -- run_monthly_accrual Tests
    -- -------------------------------------------------------------------
    --%test(run_monthly_accrual processes active employees)
    PROCEDURE test_accrual_basic;

    --%test(run_monthly_accrual respects max balance cap)
    PROCEDURE test_accrual_max_cap;

    -- -------------------------------------------------------------------
    -- process_carryover Tests
    -- -------------------------------------------------------------------
    --%test(process_carryover carries forward unused balance)
    PROCEDURE test_carryover_basic;

    -- -------------------------------------------------------------------
    -- expire_carryover Tests
    -- -------------------------------------------------------------------
    --%test(expire_carryover expires old carryover balances)
    PROCEDURE test_expire_carryover;

END UT_PKG_LEAVE;
/
