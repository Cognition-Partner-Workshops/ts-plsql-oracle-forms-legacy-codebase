CREATE OR REPLACE PACKAGE BODY HRMS.PKG_NOTIFICATION AS
-- ============================================================================
-- PKG_NOTIFICATION - Notification Queue Package Body
-- ============================================================================

    -- Hard-coded SMTP config (should be in SYSTEM_PARAMETERS)
    c_smtp_host    CONSTANT VARCHAR2(100) := 'smtp.internal.company.com';
    c_smtp_port    CONSTANT NUMBER := 25;
    c_from_address CONSTANT VARCHAR2(100) := 'hrms-noreply@company.com';
    c_from_name    CONSTANT VARCHAR2(100) := 'HRMS System';

    -- -----------------------------------------------------------------------
    -- send_notification
    -- Queues a notification for async delivery
    -- -----------------------------------------------------------------------
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
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_email VARCHAR2(100);
    BEGIN
        -- Resolve email from employee ID if not provided
        IF p_recipient_email IS NULL AND p_recipient_emp_id IS NOT NULL THEN
            BEGIN
                SELECT EMAIL INTO v_email
                FROM EMPLOYEES
                WHERE EMP_ID = p_recipient_emp_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_email := NULL;
            END;
        ELSE
            v_email := p_recipient_email;
        END IF;

        INSERT INTO NOTIFICATION_QUEUE (
            NOTIFICATION_ID, RECIPIENT_EMP_ID, RECIPIENT_EMAIL,
            NOTIFICATION_TYPE, SUBJECT, BODY,
            STATUS, PRIORITY, REFERENCE_TABLE, REFERENCE_ID,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_NOTIFICATION.NEXTVAL, p_recipient_emp_id, v_email,
            p_type, p_subject, p_body,
            'PENDING', p_priority, p_reference_table, p_reference_id,
            p_user, SYSDATE
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- Notification failures should never block business operations
            ROLLBACK;
            PKG_COMMON.log_error('PKG_NOTIFICATION', 'send_notification',
                'Failed to queue notification: ' || SQLERRM, p_user);
    END send_notification;

    -- -----------------------------------------------------------------------
    -- process_queue
    -- Sends pending notifications via UTL_SMTP
    -- Called by DBMS_SCHEDULER job every 5 minutes
    -- -----------------------------------------------------------------------
    PROCEDURE process_queue(
        p_batch_size IN NUMBER DEFAULT 50,
        p_user       IN VARCHAR2 DEFAULT USER
    ) IS
        v_connection UTL_SMTP.CONNECTION;
        v_sent       NUMBER := 0;
        v_failed     NUMBER := 0;
    BEGIN
        FOR notif_rec IN (
            SELECT NOTIFICATION_ID, RECIPIENT_EMAIL, SUBJECT, BODY,
                   NOTIFICATION_TYPE
            FROM NOTIFICATION_QUEUE
            WHERE STATUS = 'PENDING'
            AND NOTIFICATION_TYPE = 'EMAIL'
            AND RECIPIENT_EMAIL IS NOT NULL
            ORDER BY PRIORITY ASC, CREATED_DATE ASC
            FETCH FIRST p_batch_size ROWS ONLY
        ) LOOP
            BEGIN
                -- Open SMTP connection
                v_connection := UTL_SMTP.OPEN_CONNECTION(c_smtp_host, c_smtp_port);
                UTL_SMTP.HELO(v_connection, c_smtp_host);
                UTL_SMTP.MAIL(v_connection, c_from_address);
                UTL_SMTP.RCPT(v_connection, notif_rec.RECIPIENT_EMAIL);

                UTL_SMTP.OPEN_DATA(v_connection);
                UTL_SMTP.WRITE_DATA(v_connection,
                    'From: ' || c_from_name || ' <' || c_from_address || '>' || UTL_TCP.CRLF);
                UTL_SMTP.WRITE_DATA(v_connection,
                    'To: ' || notif_rec.RECIPIENT_EMAIL || UTL_TCP.CRLF);
                UTL_SMTP.WRITE_DATA(v_connection,
                    'Subject: ' || notif_rec.SUBJECT || UTL_TCP.CRLF);
                UTL_SMTP.WRITE_DATA(v_connection,
                    'Content-Type: text/plain; charset=UTF-8' || UTL_TCP.CRLF);
                UTL_SMTP.WRITE_DATA(v_connection, UTL_TCP.CRLF);
                UTL_SMTP.WRITE_DATA(v_connection, notif_rec.BODY);
                UTL_SMTP.CLOSE_DATA(v_connection);
                UTL_SMTP.QUIT(v_connection);

                -- Mark as sent
                UPDATE NOTIFICATION_QUEUE SET
                    STATUS = 'SENT',
                    SENT_DATE = SYSDATE
                WHERE NOTIFICATION_ID = notif_rec.NOTIFICATION_ID;

                v_sent := v_sent + 1;

            EXCEPTION
                WHEN OTHERS THEN
                    -- Mark as failed with error message
                    UPDATE NOTIFICATION_QUEUE SET
                        STATUS = 'FAILED',
                        ERROR_MESSAGE = SUBSTR(SQLERRM, 1, 4000),
                        RETRY_COUNT = RETRY_COUNT + 1
                    WHERE NOTIFICATION_ID = notif_rec.NOTIFICATION_ID;

                    v_failed := v_failed + 1;

                    -- Try to close connection if open
                    BEGIN
                        UTL_SMTP.QUIT(v_connection);
                    EXCEPTION
                        WHEN OTHERS THEN NULL;
                    END;
            END;
        END LOOP;

        COMMIT;

        IF v_sent > 0 OR v_failed > 0 THEN
            PKG_COMMON.log_info('PKG_NOTIFICATION', 'process_queue',
                'Processed: ' || v_sent || ' sent, ' || v_failed || ' failed', p_user);
        END IF;
    END process_queue;

    -- -----------------------------------------------------------------------
    -- retry_failed
    -- -----------------------------------------------------------------------
    PROCEDURE retry_failed(
        p_max_retries IN NUMBER DEFAULT 3,
        p_user        IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE NOTIFICATION_QUEUE SET
            STATUS = 'PENDING',
            ERROR_MESSAGE = NULL
        WHERE STATUS = 'FAILED'
        AND RETRY_COUNT < p_max_retries;

        COMMIT;
    END retry_failed;

    -- -----------------------------------------------------------------------
    -- cancel_notification
    -- -----------------------------------------------------------------------
    PROCEDURE cancel_notification(
        p_notification_id IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        UPDATE NOTIFICATION_QUEUE SET
            STATUS = 'CANCELLED'
        WHERE NOTIFICATION_ID = p_notification_id
        AND STATUS = 'PENDING';
    END cancel_notification;

END PKG_NOTIFICATION;
/
