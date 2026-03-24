-- ============================================================================
-- HRMS Leave Management Tables
-- Oracle Database 19c
-- Schema: HRMS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- LEAVE_TYPES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LEAVE_TYPES (
    LEAVE_TYPE_ID        NUMBER(5)       NOT NULL,
    LEAVE_TYPE_CODE      VARCHAR2(20)    NOT NULL,
    LEAVE_TYPE_NAME      VARCHAR2(50)    NOT NULL,
    PAID_FLAG            CHAR(1)         DEFAULT 'Y',
    ACCRUAL_FLAG         CHAR(1)         DEFAULT 'Y',
    ACCRUAL_RATE         NUMBER(6,2),
    ACCRUAL_FREQUENCY    VARCHAR2(20),
    MAX_BALANCE          NUMBER(6,2),
    CARRYOVER_MAX        NUMBER(6,2),
    CARRYOVER_EXPIRY     NUMBER(3),
    MIN_TENURE_DAYS      NUMBER(5)       DEFAULT 0,
    REQUIRES_APPROVAL    CHAR(1)         DEFAULT 'Y',
    REQUIRES_DOCUMENT    CHAR(1)         DEFAULT 'N',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_LEAVE_TYPES PRIMARY KEY (LEAVE_TYPE_ID),
    CONSTRAINT UK_LEAVE_TYPE_CODE UNIQUE (LEAVE_TYPE_CODE),
    CONSTRAINT CHK_ACCRUAL_FREQ CHECK (ACCRUAL_FREQUENCY IN ('MONTHLY', 'BIWEEKLY', 'ANNUAL', NULL))
);

-- ----------------------------------------------------------------------------
-- LEAVE_BALANCES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LEAVE_BALANCES (
    BALANCE_ID           NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    LEAVE_TYPE_ID        NUMBER(5)       NOT NULL,
    CALENDAR_YEAR        NUMBER(4)       NOT NULL,
    OPENING_BALANCE      NUMBER(6,2)     DEFAULT 0,
    ACCRUED              NUMBER(6,2)     DEFAULT 0,
    USED                 NUMBER(6,2)     DEFAULT 0,
    ADJUSTMENT           NUMBER(6,2)     DEFAULT 0,
    PENDING              NUMBER(6,2)     DEFAULT 0,
    AVAILABLE            NUMBER(6,2)     GENERATED ALWAYS AS (OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT - PENDING) VIRTUAL,
    CARRYOVER_FROM_PREV  NUMBER(6,2)     DEFAULT 0,
    CARRYOVER_EXPIRY_DT  DATE,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_LEAVE_BALANCES PRIMARY KEY (BALANCE_ID),
    CONSTRAINT FK_LB_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_LB_TYPE FOREIGN KEY (LEAVE_TYPE_ID) REFERENCES HRMS.LEAVE_TYPES(LEAVE_TYPE_ID),
    CONSTRAINT UK_LEAVE_BAL UNIQUE (EMP_ID, LEAVE_TYPE_ID, CALENDAR_YEAR)
);

-- ----------------------------------------------------------------------------
-- LEAVE_REQUESTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LEAVE_REQUESTS (
    REQUEST_ID           NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    LEAVE_TYPE_ID        NUMBER(5)       NOT NULL,
    START_DATE           DATE            NOT NULL,
    END_DATE             DATE            NOT NULL,
    TOTAL_DAYS           NUMBER(5,1)     NOT NULL,
    HALF_DAY_FLAG        CHAR(1)         DEFAULT 'N',
    HALF_DAY_PERIOD      VARCHAR2(10),
    STATUS               VARCHAR2(20)    DEFAULT 'PENDING',
    REASON               VARCHAR2(4000),
    SUPPORTING_DOC_PATH  VARCHAR2(500),
    APPROVER_EMP_ID      NUMBER(10),
    APPROVAL_DATE        DATE,
    APPROVAL_COMMENTS    VARCHAR2(4000),
    CANCEL_REASON        VARCHAR2(4000),
    CANCELLED_DATE       DATE,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_LEAVE_REQUESTS PRIMARY KEY (REQUEST_ID),
    CONSTRAINT FK_LR_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_LR_TYPE FOREIGN KEY (LEAVE_TYPE_ID) REFERENCES HRMS.LEAVE_TYPES(LEAVE_TYPE_ID),
    CONSTRAINT FK_LR_APPROVER FOREIGN KEY (APPROVER_EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_LR_STATUS CHECK (STATUS IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'TAKEN')),
    CONSTRAINT CHK_LR_DATES CHECK (END_DATE >= START_DATE),
    CONSTRAINT CHK_HALF_DAY CHECK (HALF_DAY_PERIOD IN ('AM', 'PM', NULL))
);

-- ----------------------------------------------------------------------------
-- LEAVE_ACCRUAL_LOG
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LEAVE_ACCRUAL_LOG (
    ACCRUAL_ID           NUMBER(15)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    LEAVE_TYPE_ID        NUMBER(5)       NOT NULL,
    ACCRUAL_DATE         DATE            NOT NULL,
    ACCRUAL_AMOUNT       NUMBER(6,2)     NOT NULL,
    BALANCE_AFTER        NUMBER(6,2),
    RUN_ID               NUMBER(10),
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_LEAVE_ACCRUAL_LOG PRIMARY KEY (ACCRUAL_ID),
    CONSTRAINT FK_LAL_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_LAL_TYPE FOREIGN KEY (LEAVE_TYPE_ID) REFERENCES HRMS.LEAVE_TYPES(LEAVE_TYPE_ID)
);

-- ----------------------------------------------------------------------------
-- HOLIDAYS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.HOLIDAYS (
    HOLIDAY_ID           NUMBER(5)       NOT NULL,
    HOLIDAY_DATE         DATE            NOT NULL,
    HOLIDAY_NAME         VARCHAR2(100)   NOT NULL,
    LOCATION_CODE        VARCHAR2(10),
    FLOATING_FLAG        CHAR(1)         DEFAULT 'N',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_HOLIDAYS PRIMARY KEY (HOLIDAY_ID)
);
