CREATE OR REPLACE PACKAGE HRMS.PKG_NOTIFICATION AS
-- ============================================================================
-- PKG_NOTIFICATION - Notification Queue Package
-- Email, in-app, and SMS notification management
--
-- Dependencies: PKG_COMMON
-- Called by: PKG_EMPLOYEE, PKG_LEAVE, PKG_PAYROLL, PKG_PERFORMANCE
-- Known issues:
--   - UTL_MAIL configuration hard-coded to legacy SMTP server
--   - No rate limiting - bulk operations can flood the queue
--   - HTML email templates stored as string constants (maintenance nightmare)
-- ============================================================================

    PROCEDURE send_notification(
        p_recipient_emp_id IN NUMBER DEFAULT NULL,
        p_recipient_email  IN VARCHAR2 DEFAULT NULL,
        p_type             IN VARCHAR2 DEFAULT 'EMAIL',
        p_subject          IN VARCHAR2,
        p_body             IN CLOB,
        p_priority         IN NUMBER DEFAULT 5,
        p_reference_table  IN VARCHAR2 DEFAULT NULL,
        p_reference_id     IN NUMBER DEFAULT NULL,
        p_user             IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE process_queue(
        p_batch_size IN NUMBER DEFAULT 50,
        p_user       IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE retry_failed(
        p_max_retries IN NUMBER DEFAULT 3,
        p_user        IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE cancel_notification(
        p_notification_id IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    );

END PKG_NOTIFICATION;
/
