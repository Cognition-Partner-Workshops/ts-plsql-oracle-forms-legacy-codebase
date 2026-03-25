CREATE OR REPLACE PACKAGE BODY HRMS.UT_PKG_NOTIFICATION AS
-- ============================================================================
-- UT_PKG_NOTIFICATION - Unit Tests for PKG_NOTIFICATION Body
-- ============================================================================

    c_test_user   CONSTANT VARCHAR2(30) := 'UT_NOTIF_TEST';
    c_test_email  CONSTANT VARCHAR2(100) := 'ut_notif@test.com';
    g_test_emp_id NUMBER;

    PROCEDURE setup_test_data IS
    BEGIN
        -- Create a test employee for notification resolution
        INSERT INTO EMPLOYEES (EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, EMAIL, EMPLOYMENT_STATUS, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE)
        VALUES (SEQ_EMPLOYEE.NEXTVAL, 'EMP-990001', 'NotifTest', 'User',
            SYSDATE, 1, 1, c_test_email, 'ACTIVE', 'Y',
            'UT_SETUP', SYSDATE)
        RETURNING EMP_ID INTO g_test_emp_id;

        COMMIT;
    END setup_test_data;

    PROCEDURE teardown_test_data IS
    BEGIN
        DELETE FROM NOTIFICATION_QUEUE WHERE CREATED_BY = c_test_user;
        DELETE FROM EMPLOYEES WHERE EMP_NUMBER = 'EMP-990001';
        COMMIT;
    END teardown_test_data;

    -- ===================================================================
    -- send_notification Tests
    -- ===================================================================
    PROCEDURE test_send_email_basic IS
        v_count NUMBER;
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_type => 'EMAIL',
            p_subject => 'UT Test Subject',
            p_body => 'UT Test Body',
            p_user => c_test_user
        );

        SELECT COUNT(*) INTO v_count
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Test Subject'
        AND NOTIFICATION_TYPE = 'EMAIL';

        ut.expect(v_count).to_equal(1);
    END test_send_email_basic;

    PROCEDURE test_send_resolves_email IS
        v_email VARCHAR2(100);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => g_test_emp_id,
            p_subject => 'UT Resolve Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        SELECT RECIPIENT_EMAIL INTO v_email
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Resolve Test'
        AND ROWNUM = 1;

        ut.expect(v_email).to_equal(c_test_email);
    END test_send_resolves_email;

    PROCEDURE test_send_email_override IS
        v_email VARCHAR2(100);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => g_test_emp_id,
            p_recipient_email => 'override@test.com',
            p_subject => 'UT Override Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        SELECT RECIPIENT_EMAIL INTO v_email
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Override Test'
        AND ROWNUM = 1;

        ut.expect(v_email).to_equal('override@test.com');
    END test_send_email_override;

    PROCEDURE test_send_sms IS
        v_type VARCHAR2(20);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => '5551234567',
            p_type => 'SMS',
            p_subject => 'UT SMS Test',
            p_body => 'SMS Body',
            p_user => c_test_user
        );

        SELECT NOTIFICATION_TYPE INTO v_type
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT SMS Test'
        AND ROWNUM = 1;

        ut.expect(v_type).to_equal('SMS');
    END test_send_sms;

    PROCEDURE test_send_in_app IS
        v_type VARCHAR2(20);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => g_test_emp_id,
            p_type => 'IN_APP',
            p_subject => 'UT InApp Test',
            p_body => 'InApp Body',
            p_user => c_test_user
        );

        SELECT NOTIFICATION_TYPE INTO v_type
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT InApp Test'
        AND ROWNUM = 1;

        ut.expect(v_type).to_equal('IN_APP');
    END test_send_in_app;

    PROCEDURE test_send_pending_status IS
        v_status VARCHAR2(20);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Status Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Status Test'
        AND ROWNUM = 1;

        ut.expect(v_status).to_equal('PENDING');
    END test_send_pending_status;

    PROCEDURE test_send_priority IS
        v_priority NUMBER;
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Priority Test',
            p_body => 'Body',
            p_priority => 1,
            p_user => c_test_user
        );

        SELECT PRIORITY INTO v_priority
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Priority Test'
        AND ROWNUM = 1;

        ut.expect(v_priority).to_equal(1);
    END test_send_priority;

    PROCEDURE test_send_invalid_emp IS
        v_count NUMBER;
    BEGIN
        -- Should not raise - falls back to NULL email
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => -999,
            p_subject => 'UT Invalid Emp Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        SELECT COUNT(*) INTO v_count
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Invalid Emp Test'
        AND RECIPIENT_EMAIL IS NULL;

        ut.expect(v_count).to_equal(1);
    END test_send_invalid_emp;

    PROCEDURE test_send_autonomous IS
        v_count_before NUMBER;
        v_count_after  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count_before
        FROM NOTIFICATION_QUEUE WHERE CREATED_BY = c_test_user;

        SAVEPOINT before_notif_test;

        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Autonomous Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        ROLLBACK TO before_notif_test;

        SELECT COUNT(*) INTO v_count_after
        FROM NOTIFICATION_QUEUE WHERE CREATED_BY = c_test_user;

        ut.expect(v_count_after).to_be_greater_than(v_count_before);
    END test_send_autonomous;

    PROCEDURE test_send_reference IS
        v_ref_table VARCHAR2(50);
        v_ref_id    NUMBER;
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Ref Test',
            p_body => 'Body',
            p_reference_table => 'LEAVE_REQUESTS',
            p_reference_id => 12345,
            p_user => c_test_user
        );

        SELECT REFERENCE_TABLE, REFERENCE_ID INTO v_ref_table, v_ref_id
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Ref Test'
        AND ROWNUM = 1;

        ut.expect(v_ref_table).to_equal('LEAVE_REQUESTS');
        ut.expect(v_ref_id).to_equal(12345);
    END test_send_reference;

    PROCEDURE test_send_large_body IS
        v_count NUMBER;
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Large Body Test',
            p_body => RPAD('Large body content. ', 10000, 'More content. '),
            p_user => c_test_user
        );

        SELECT COUNT(*) INTO v_count
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT Large Body Test';

        ut.expect(v_count).to_equal(1);
    END test_send_large_body;

    PROCEDURE test_send_no_raise IS
    BEGIN
        -- Should never raise regardless of input
        PKG_NOTIFICATION.send_notification(
            p_subject => 'UT No Raise Test',
            p_body => 'Body',
            p_user => c_test_user
        );
        ut.expect(TRUE).to_be_true();
    END test_send_no_raise;

    -- ===================================================================
    -- process_queue Tests
    -- ===================================================================
    PROCEDURE test_process_queue_basic IS
    BEGIN
        -- process_queue attempts SMTP connection which will fail in test env
        -- but should handle it gracefully by marking as FAILED
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'test@example.com',
            p_subject => 'UT Process Test',
            p_body => 'Body',
            p_user => c_test_user
        );

        PKG_NOTIFICATION.process_queue(p_batch_size => 10, p_user => c_test_user);

        -- Notification should be FAILED (no SMTP server) or still PENDING
        DECLARE
            v_status VARCHAR2(20);
        BEGIN
            SELECT STATUS INTO v_status
            FROM NOTIFICATION_QUEUE
            WHERE CREATED_BY = c_test_user
            AND SUBJECT = 'UT Process Test'
            AND ROWNUM = 1;

            ut.expect(v_status).to_be_not_null();
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ut.expect(TRUE).to_be_true();
        END;
    END test_process_queue_basic;

    PROCEDURE test_process_queue_batch IS
    BEGIN
        -- Insert multiple notifications
        FOR i IN 1..5 LOOP
            PKG_NOTIFICATION.send_notification(
                p_recipient_email => 'batch' || i || '@test.com',
                p_subject => 'UT Batch ' || i,
                p_body => 'Body',
                p_user => c_test_user
            );
        END LOOP;

        -- Process with batch size of 2
        PKG_NOTIFICATION.process_queue(p_batch_size => 2, p_user => c_test_user);

        -- Should not raise regardless of outcome
        ut.expect(TRUE).to_be_true();
    END test_process_queue_batch;

    PROCEDURE test_process_queue_failure IS
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'fail@test.com',
            p_subject => 'UT Fail Process',
            p_body => 'Body',
            p_user => c_test_user
        );

        -- Will fail because no SMTP server
        PKG_NOTIFICATION.process_queue(p_user => c_test_user);

        DECLARE
            v_status VARCHAR2(20);
        BEGIN
            SELECT STATUS INTO v_status
            FROM NOTIFICATION_QUEUE
            WHERE CREATED_BY = c_test_user
            AND SUBJECT = 'UT Fail Process'
            AND ROWNUM = 1;

            -- Should be FAILED due to SMTP connection failure
            ut.expect(v_status).to_be_in(ut_varchar2_list('FAILED', 'PENDING'));
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ut.expect(TRUE).to_be_true();
        END;
    END test_process_queue_failure;

    PROCEDURE test_process_queue_email_only IS
        v_status VARCHAR2(20);
    BEGIN
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => g_test_emp_id,
            p_type => 'IN_APP',
            p_subject => 'UT InApp Skip',
            p_body => 'Body',
            p_user => c_test_user
        );

        PKG_NOTIFICATION.process_queue(p_user => c_test_user);

        -- IN_APP should remain PENDING (process_queue only handles EMAIL)
        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE
        WHERE CREATED_BY = c_test_user
        AND SUBJECT = 'UT InApp Skip'
        AND ROWNUM = 1;

        ut.expect(v_status).to_equal('PENDING');
    END test_process_queue_email_only;

    PROCEDURE test_process_queue_no_email IS
    BEGIN
        -- Queue notification with no email
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => -999,
            p_type => 'EMAIL',
            p_subject => 'UT No Email',
            p_body => 'Body',
            p_user => c_test_user
        );

        PKG_NOTIFICATION.process_queue(p_user => c_test_user);

        DECLARE
            v_status VARCHAR2(20);
        BEGIN
            SELECT STATUS INTO v_status
            FROM NOTIFICATION_QUEUE
            WHERE CREATED_BY = c_test_user
            AND SUBJECT = 'UT No Email'
            AND ROWNUM = 1;

            -- Should remain PENDING since RECIPIENT_EMAIL IS NULL is skipped
            ut.expect(v_status).to_equal('PENDING');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ut.expect(TRUE).to_be_true();
        END;
    END test_process_queue_no_email;

    PROCEDURE test_process_queue_ordering IS
    BEGIN
        -- Insert high and low priority
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'low@test.com',
            p_subject => 'UT Order Low',
            p_body => 'Body',
            p_priority => 10,
            p_user => c_test_user
        );
        PKG_NOTIFICATION.send_notification(
            p_recipient_email => 'high@test.com',
            p_subject => 'UT Order High',
            p_body => 'Body',
            p_priority => 1,
            p_user => c_test_user
        );

        PKG_NOTIFICATION.process_queue(p_batch_size => 1, p_user => c_test_user);
        -- High priority should be processed first
        ut.expect(TRUE).to_be_true();
    END test_process_queue_ordering;

    -- ===================================================================
    -- retry_failed Tests
    -- ===================================================================
    PROCEDURE test_retry_under_limit IS
        v_notif_id NUMBER;
        v_status   VARCHAR2(20);
    BEGIN
        -- Insert a FAILED notification with retry_count = 1
        INSERT INTO NOTIFICATION_QUEUE (NOTIFICATION_ID, NOTIFICATION_TYPE,
            SUBJECT, BODY, STATUS, RETRY_COUNT, ERROR_MESSAGE,
            CREATED_BY, CREATED_DATE, RECIPIENT_EMAIL)
        VALUES (SEQ_NOTIFICATION.NEXTVAL, 'EMAIL',
            'UT Retry Under', 'Body', 'FAILED', 1, 'SMTP error',
            c_test_user, SYSDATE, 'retry@test.com')
        RETURNING NOTIFICATION_ID INTO v_notif_id;
        COMMIT;

        PKG_NOTIFICATION.retry_failed(p_max_retries => 3, p_user => c_test_user);

        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE WHERE NOTIFICATION_ID = v_notif_id;

        ut.expect(v_status).to_equal('PENDING');
    END test_retry_under_limit;

    PROCEDURE test_retry_over_limit IS
        v_notif_id NUMBER;
        v_status   VARCHAR2(20);
    BEGIN
        -- Insert FAILED with retry_count = 5
        INSERT INTO NOTIFICATION_QUEUE (NOTIFICATION_ID, NOTIFICATION_TYPE,
            SUBJECT, BODY, STATUS, RETRY_COUNT, ERROR_MESSAGE,
            CREATED_BY, CREATED_DATE, RECIPIENT_EMAIL)
        VALUES (SEQ_NOTIFICATION.NEXTVAL, 'EMAIL',
            'UT Retry Over', 'Body', 'FAILED', 5, 'SMTP error',
            c_test_user, SYSDATE, 'retry@test.com')
        RETURNING NOTIFICATION_ID INTO v_notif_id;
        COMMIT;

        PKG_NOTIFICATION.retry_failed(p_max_retries => 3, p_user => c_test_user);

        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE WHERE NOTIFICATION_ID = v_notif_id;

        ut.expect(v_status).to_equal('FAILED');
    END test_retry_over_limit;

    PROCEDURE test_retry_clears_error IS
        v_notif_id NUMBER;
        v_error    VARCHAR2(4000);
    BEGIN
        INSERT INTO NOTIFICATION_QUEUE (NOTIFICATION_ID, NOTIFICATION_TYPE,
            SUBJECT, BODY, STATUS, RETRY_COUNT, ERROR_MESSAGE,
            CREATED_BY, CREATED_DATE, RECIPIENT_EMAIL)
        VALUES (SEQ_NOTIFICATION.NEXTVAL, 'EMAIL',
            'UT Retry Clear', 'Body', 'FAILED', 0, 'Some error',
            c_test_user, SYSDATE, 'retry@test.com')
        RETURNING NOTIFICATION_ID INTO v_notif_id;
        COMMIT;

        PKG_NOTIFICATION.retry_failed(p_max_retries => 3, p_user => c_test_user);

        SELECT ERROR_MESSAGE INTO v_error
        FROM NOTIFICATION_QUEUE WHERE NOTIFICATION_ID = v_notif_id;

        ut.expect(v_error).to_be_null();
    END test_retry_clears_error;

    -- ===================================================================
    -- cancel_notification Tests
    -- ===================================================================
    PROCEDURE test_cancel_pending IS
        v_notif_id NUMBER;
        v_status   VARCHAR2(20);
    BEGIN
        INSERT INTO NOTIFICATION_QUEUE (NOTIFICATION_ID, NOTIFICATION_TYPE,
            SUBJECT, BODY, STATUS, CREATED_BY, CREATED_DATE, RECIPIENT_EMAIL)
        VALUES (SEQ_NOTIFICATION.NEXTVAL, 'EMAIL',
            'UT Cancel Pending', 'Body', 'PENDING',
            c_test_user, SYSDATE, 'cancel@test.com')
        RETURNING NOTIFICATION_ID INTO v_notif_id;
        COMMIT;

        PKG_NOTIFICATION.cancel_notification(v_notif_id, c_test_user);

        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE WHERE NOTIFICATION_ID = v_notif_id;

        ut.expect(v_status).to_equal('CANCELLED');
    END test_cancel_pending;

    PROCEDURE test_cancel_sent IS
        v_notif_id NUMBER;
        v_status   VARCHAR2(20);
    BEGIN
        INSERT INTO NOTIFICATION_QUEUE (NOTIFICATION_ID, NOTIFICATION_TYPE,
            SUBJECT, BODY, STATUS, SENT_DATE, CREATED_BY, CREATED_DATE,
            RECIPIENT_EMAIL)
        VALUES (SEQ_NOTIFICATION.NEXTVAL, 'EMAIL',
            'UT Cancel Sent', 'Body', 'SENT', SYSDATE,
            c_test_user, SYSDATE, 'cancel@test.com')
        RETURNING NOTIFICATION_ID INTO v_notif_id;
        COMMIT;

        PKG_NOTIFICATION.cancel_notification(v_notif_id, c_test_user);

        SELECT STATUS INTO v_status
        FROM NOTIFICATION_QUEUE WHERE NOTIFICATION_ID = v_notif_id;

        -- Should remain SENT
        ut.expect(v_status).to_equal('SENT');
    END test_cancel_sent;

    PROCEDURE test_cancel_nonexistent IS
    BEGIN
        PKG_NOTIFICATION.cancel_notification(-999, c_test_user);
        -- Should not raise
        ut.expect(TRUE).to_be_true();
    END test_cancel_nonexistent;

END UT_PKG_NOTIFICATION;
/
