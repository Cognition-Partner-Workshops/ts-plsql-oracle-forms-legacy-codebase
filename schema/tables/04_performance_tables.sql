-- ============================================================================
-- HRMS Performance Management Tables
-- Oracle Database 19c
-- Schema: HRMS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- REVIEW_CYCLES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.REVIEW_CYCLES (
    CYCLE_ID             NUMBER(10)      NOT NULL,
    CYCLE_NAME           VARCHAR2(100)   NOT NULL,
    CYCLE_YEAR           NUMBER(4)       NOT NULL,
    START_DATE           DATE            NOT NULL,
    END_DATE             DATE            NOT NULL,
    SELF_REVIEW_DUE      DATE,
    MANAGER_REVIEW_DUE   DATE,
    CALIBRATION_DUE      DATE,
    STATUS               VARCHAR2(20)    DEFAULT 'DRAFT',
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_REVIEW_CYCLES PRIMARY KEY (CYCLE_ID),
    CONSTRAINT CHK_CYCLE_STATUS CHECK (STATUS IN ('DRAFT', 'OPEN', 'IN_PROGRESS', 'CALIBRATION', 'CLOSED'))
);

-- ----------------------------------------------------------------------------
-- PERFORMANCE_REVIEWS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PERFORMANCE_REVIEWS (
    REVIEW_ID            NUMBER(10)      NOT NULL,
    CYCLE_ID             NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    REVIEWER_EMP_ID      NUMBER(10)      NOT NULL,
    REVIEW_TYPE          VARCHAR2(20)    DEFAULT 'ANNUAL',
    STATUS               VARCHAR2(20)    DEFAULT 'NOT_STARTED',
    OVERALL_RATING       NUMBER(2,1),
    RATING_LABEL         VARCHAR2(50),
    SELF_ASSESSMENT      CLOB,
    MANAGER_ASSESSMENT   CLOB,
    STRENGTHS            CLOB,
    AREAS_FOR_IMPROVEMENT CLOB,
    DEVELOPMENT_PLAN     CLOB,
    EMPLOYEE_COMMENTS    CLOB,
    EMPLOYEE_ACK_DATE    DATE,
    CALIBRATED_RATING    NUMBER(2,1),
    CALIBRATION_NOTES    VARCHAR2(4000),
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_PERFORMANCE_REVIEWS PRIMARY KEY (REVIEW_ID),
    CONSTRAINT FK_PR_CYCLE FOREIGN KEY (CYCLE_ID) REFERENCES HRMS.REVIEW_CYCLES(CYCLE_ID),
    CONSTRAINT FK_PR_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_PR_REVIEWER FOREIGN KEY (REVIEWER_EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_REVIEW_STATUS CHECK (STATUS IN ('NOT_STARTED', 'SELF_REVIEW', 'MANAGER_REVIEW', 'MEETING_SCHEDULED', 'COMPLETED', 'ACKNOWLEDGED')),
    CONSTRAINT CHK_RATING_RANGE CHECK (OVERALL_RATING BETWEEN 1.0 AND 5.0)
);

-- ----------------------------------------------------------------------------
-- PERFORMANCE_GOALS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PERFORMANCE_GOALS (
    GOAL_ID              NUMBER(10)      NOT NULL,
    REVIEW_ID            NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    GOAL_TITLE           VARCHAR2(200)   NOT NULL,
    GOAL_DESCRIPTION     CLOB,
    GOAL_CATEGORY        VARCHAR2(30),
    WEIGHT_PCT           NUMBER(5,2)     DEFAULT 0,
    TARGET_DATE          DATE,
    STATUS               VARCHAR2(20)    DEFAULT 'NOT_STARTED',
    PROGRESS_PCT         NUMBER(5,2)     DEFAULT 0,
    SELF_RATING          NUMBER(2,1),
    MANAGER_RATING       NUMBER(2,1),
    COMMENTS             CLOB,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_PERF_GOALS PRIMARY KEY (GOAL_ID),
    CONSTRAINT FK_PG_REVIEW FOREIGN KEY (REVIEW_ID) REFERENCES HRMS.PERFORMANCE_REVIEWS(REVIEW_ID),
    CONSTRAINT FK_PG_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_GOAL_STATUS CHECK (STATUS IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'DEFERRED', 'CANCELLED')),
    CONSTRAINT CHK_GOAL_CATEGORY CHECK (GOAL_CATEGORY IN ('BUSINESS', 'DEVELOPMENT', 'LEADERSHIP', 'INNOVATION', 'COMPLIANCE'))
);

-- ----------------------------------------------------------------------------
-- AUDIT_LOG (cross-cutting)
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.AUDIT_LOG (
    AUDIT_ID             NUMBER(15)      NOT NULL,
    TABLE_NAME           VARCHAR2(60)    NOT NULL,
    RECORD_ID            NUMBER(15)      NOT NULL,
    ACTION_TYPE          VARCHAR2(10)    NOT NULL,
    OLD_VALUES           CLOB,
    NEW_VALUES           CLOB,
    CHANGED_BY           VARCHAR2(30)    NOT NULL,
    CHANGED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    IP_ADDRESS           VARCHAR2(50),
    SESSION_ID           VARCHAR2(100),
    CONSTRAINT PK_AUDIT_LOG PRIMARY KEY (AUDIT_ID),
    CONSTRAINT CHK_AUDIT_ACTION CHECK (ACTION_TYPE IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- ----------------------------------------------------------------------------
-- SYSTEM_PARAMETERS (configuration)
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.SYSTEM_PARAMETERS (
    PARAM_ID             NUMBER(5)       NOT NULL,
    PARAM_GROUP          VARCHAR2(50)    NOT NULL,
    PARAM_CODE           VARCHAR2(50)    NOT NULL,
    PARAM_VALUE          VARCHAR2(4000)  NOT NULL,
    PARAM_DESCRIPTION    VARCHAR2(200),
    DATA_TYPE            VARCHAR2(20)    DEFAULT 'VARCHAR2',
    EDITABLE_FLAG        CHAR(1)         DEFAULT 'Y',
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_SYSTEM_PARAMS PRIMARY KEY (PARAM_ID),
    CONSTRAINT UK_PARAM_CODE UNIQUE (PARAM_GROUP, PARAM_CODE)
);

-- ----------------------------------------------------------------------------
-- NOTIFICATION_QUEUE
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.NOTIFICATION_QUEUE (
    NOTIFICATION_ID      NUMBER(15)      NOT NULL,
    RECIPIENT_EMP_ID     NUMBER(10),
    RECIPIENT_EMAIL      VARCHAR2(100),
    NOTIFICATION_TYPE    VARCHAR2(30)    NOT NULL,
    SUBJECT              VARCHAR2(200)   NOT NULL,
    BODY                 CLOB            NOT NULL,
    STATUS               VARCHAR2(20)    DEFAULT 'PENDING',
    PRIORITY             NUMBER(2)       DEFAULT 5,
    SENT_DATE            DATE,
    ERROR_MESSAGE        VARCHAR2(4000),
    RETRY_COUNT          NUMBER(3)       DEFAULT 0,
    REFERENCE_TABLE      VARCHAR2(60),
    REFERENCE_ID         NUMBER(15),
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_NOTIF_QUEUE PRIMARY KEY (NOTIFICATION_ID),
    CONSTRAINT CHK_NOTIF_STATUS CHECK (STATUS IN ('PENDING', 'SENT', 'FAILED', 'CANCELLED')),
    CONSTRAINT CHK_NOTIF_TYPE CHECK (NOTIFICATION_TYPE IN ('EMAIL', 'IN_APP', 'SMS'))
);

-- ----------------------------------------------------------------------------
-- USER_SESSIONS (Forms-specific session tracking)
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.USER_SESSIONS (
    SESSION_ID           NUMBER(15)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    USERNAME             VARCHAR2(30)    NOT NULL,
    LOGIN_TIME           DATE            NOT NULL,
    LOGOUT_TIME          DATE,
    IP_ADDRESS           VARCHAR2(50),
    FORMS_MODULE         VARCHAR2(100),
    SESSION_STATUS       VARCHAR2(20)    DEFAULT 'ACTIVE',
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_USER_SESSIONS PRIMARY KEY (SESSION_ID),
    CONSTRAINT FK_US_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID)
);

-- ----------------------------------------------------------------------------
-- LOOKUP_VALUES (generic lookup table)
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LOOKUP_VALUES (
    LOOKUP_ID            NUMBER(10)      NOT NULL,
    LOOKUP_TYPE          VARCHAR2(50)    NOT NULL,
    LOOKUP_CODE          VARCHAR2(50)    NOT NULL,
    LOOKUP_VALUE         VARCHAR2(200)   NOT NULL,
    DISPLAY_ORDER        NUMBER(5)       DEFAULT 0,
    PARENT_LOOKUP_ID     NUMBER(10),
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_LOOKUP_VALUES PRIMARY KEY (LOOKUP_ID),
    CONSTRAINT UK_LOOKUP UNIQUE (LOOKUP_TYPE, LOOKUP_CODE)
);
