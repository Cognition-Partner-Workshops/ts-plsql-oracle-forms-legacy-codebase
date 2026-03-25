CREATE OR REPLACE PACKAGE HRMS.UT_PKG_NOTIFICATION AS
-- ============================================================================
-- UT_PKG_NOTIFICATION - Unit Tests for PKG_NOTIFICATION
-- Framework: utPLSQL v3
-- Coverage target: >85% of PKG_NOTIFICATION body
-- ============================================================================

    --%suite(PKG_NOTIFICATION - Notification Queue Package)
    --%suitepath(hrms.notification)

    --%beforeall
    PROCEDURE setup_test_data;

    --%afterall
    PROCEDURE teardown_test_data;

    -- -------------------------------------------------------------------
    -- send_notification Tests
    -- -------------------------------------------------------------------
    --%test(send_notification queues an EMAIL notification)
    PROCEDURE test_send_email_basic;

    --%test(send_notification resolves email from emp_id when not provided)
    PROCEDURE test_send_resolves_email;

    --%test(send_notification uses provided email even when emp_id given)
    PROCEDURE test_send_email_override;

    --%test(send_notification queues SMS notification)
    PROCEDURE test_send_sms;

    --%test(send_notification queues IN_APP notification)
    PROCEDURE test_send_in_app;

    --%test(send_notification sets status to PENDING)
    PROCEDURE test_send_pending_status;

    --%test(send_notification sets priority correctly)
    PROCEDURE test_send_priority;

    --%test(send_notification handles non-existent emp_id gracefully)
    PROCEDURE test_send_invalid_emp;

    --%test(send_notification is autonomous - survives caller rollback)
    PROCEDURE test_send_autonomous;

    --%test(send_notification captures reference_table and reference_id)
    PROCEDURE test_send_reference;

    --%test(send_notification handles CLOB body)
    PROCEDURE test_send_large_body;

    --%test(send_notification does not raise on failure)
    PROCEDURE test_send_no_raise;

    -- -------------------------------------------------------------------
    -- process_queue Tests
    -- -------------------------------------------------------------------
    --%test(process_queue processes pending EMAIL notifications)
    PROCEDURE test_process_queue_basic;

    --%test(process_queue respects batch_size limit)
    PROCEDURE test_process_queue_batch;

    --%test(process_queue marks failed notifications on SMTP error)
    PROCEDURE test_process_queue_failure;

    --%test(process_queue skips non-EMAIL types)
    PROCEDURE test_process_queue_email_only;

    --%test(process_queue skips notifications without recipient email)
    PROCEDURE test_process_queue_no_email;

    --%test(process_queue orders by priority ASC then date ASC)
    PROCEDURE test_process_queue_ordering;

    -- -------------------------------------------------------------------
    -- retry_failed Tests
    -- -------------------------------------------------------------------
    --%test(retry_failed resets FAILED to PENDING when under max retries)
    PROCEDURE test_retry_under_limit;

    --%test(retry_failed does not reset when retry_count >= max_retries)
    PROCEDURE test_retry_over_limit;

    --%test(retry_failed clears error message)
    PROCEDURE test_retry_clears_error;

    -- -------------------------------------------------------------------
    -- cancel_notification Tests
    -- -------------------------------------------------------------------
    --%test(cancel_notification sets status to CANCELLED for PENDING)
    PROCEDURE test_cancel_pending;

    --%test(cancel_notification does not cancel already SENT notifications)
    PROCEDURE test_cancel_sent;

    --%test(cancel_notification does nothing for non-existent ID)
    PROCEDURE test_cancel_nonexistent;

END UT_PKG_NOTIFICATION;
/
