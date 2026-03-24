-- ============================================================================
-- HRMS Payroll Tables
-- Oracle Database 19c
-- Schema: HRMS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SALARY_RECORDS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.SALARY_RECORDS (
    SALARY_ID            NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    EFFECTIVE_DATE       DATE            NOT NULL,
    END_DATE             DATE,
    BASE_SALARY          NUMBER(12,2)    NOT NULL,
    CURRENCY_CODE        VARCHAR2(3)     DEFAULT 'USD',
    PAY_FREQUENCY        VARCHAR2(20)    DEFAULT 'MONTHLY',
    SALARY_BASIS         VARCHAR2(20)    DEFAULT 'ANNUAL',
    CHANGE_REASON        VARCHAR2(50),
    CHANGE_PCT           NUMBER(5,2),
    APPROVED_BY          NUMBER(10),
    APPROVAL_DATE        DATE,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_SALARY_RECORDS PRIMARY KEY (SALARY_ID),
    CONSTRAINT FK_SAL_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_PAY_FREQ CHECK (PAY_FREQUENCY IN ('WEEKLY', 'BIWEEKLY', 'SEMIMONTHLY', 'MONTHLY')),
    CONSTRAINT CHK_SAL_BASIS CHECK (SALARY_BASIS IN ('ANNUAL', 'HOURLY'))
);

-- ----------------------------------------------------------------------------
-- PAY_ELEMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PAY_ELEMENTS (
    ELEMENT_ID           NUMBER(10)      NOT NULL,
    ELEMENT_CODE         VARCHAR2(30)    NOT NULL,
    ELEMENT_NAME         VARCHAR2(100)   NOT NULL,
    ELEMENT_TYPE         VARCHAR2(20)    NOT NULL,
    CALCULATION_TYPE     VARCHAR2(20)    NOT NULL,
    DEFAULT_AMOUNT       NUMBER(12,2),
    DEFAULT_PERCENTAGE   NUMBER(5,2),
    TAXABLE_FLAG         CHAR(1)         DEFAULT 'Y',
    PRETAX_FLAG          CHAR(1)         DEFAULT 'N',
    EMPLOYER_PAID        CHAR(1)         DEFAULT 'N',
    GL_ACCOUNT_CODE      VARCHAR2(30),
    PRIORITY_ORDER       NUMBER(5)       DEFAULT 100,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_PAY_ELEMENTS PRIMARY KEY (ELEMENT_ID),
    CONSTRAINT UK_PAY_ELEM_CODE UNIQUE (ELEMENT_CODE),
    CONSTRAINT CHK_ELEM_TYPE CHECK (ELEMENT_TYPE IN ('EARNING', 'DEDUCTION', 'TAX', 'BENEFIT', 'REIMBURSEMENT')),
    CONSTRAINT CHK_CALC_TYPE CHECK (CALCULATION_TYPE IN ('FLAT', 'PERCENTAGE', 'HOURS', 'FORMULA'))
);

-- ----------------------------------------------------------------------------
-- EMPLOYEE_PAY_ELEMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEE_PAY_ELEMENTS (
    EMP_ELEMENT_ID       NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    ELEMENT_ID           NUMBER(10)      NOT NULL,
    EFFECTIVE_DATE       DATE            NOT NULL,
    END_DATE             DATE,
    AMOUNT               NUMBER(12,2),
    PERCENTAGE           NUMBER(5,2),
    OVERRIDE_AMOUNT      NUMBER(12,2),
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMP_PAY_ELEMENTS PRIMARY KEY (EMP_ELEMENT_ID),
    CONSTRAINT FK_EPE_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_EPE_ELEMENT FOREIGN KEY (ELEMENT_ID) REFERENCES HRMS.PAY_ELEMENTS(ELEMENT_ID)
);

-- ----------------------------------------------------------------------------
-- PAY_PERIODS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PAY_PERIODS (
    PERIOD_ID            NUMBER(10)      NOT NULL,
    PERIOD_NAME          VARCHAR2(50)    NOT NULL,
    PAY_FREQUENCY        VARCHAR2(20)    NOT NULL,
    PERIOD_START_DATE    DATE            NOT NULL,
    PERIOD_END_DATE      DATE            NOT NULL,
    PAY_DATE             DATE            NOT NULL,
    STATUS               VARCHAR2(20)    DEFAULT 'OPEN',
    CLOSED_BY            VARCHAR2(30),
    CLOSED_DATE          DATE,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_PAY_PERIODS PRIMARY KEY (PERIOD_ID),
    CONSTRAINT CHK_PERIOD_STATUS CHECK (STATUS IN ('OPEN', 'PROCESSING', 'CLOSED', 'REVERSED'))
);

-- ----------------------------------------------------------------------------
-- PAYROLL_RUNS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PAYROLL_RUNS (
    RUN_ID               NUMBER(10)      NOT NULL,
    PERIOD_ID            NUMBER(10)      NOT NULL,
    RUN_TYPE             VARCHAR2(20)    DEFAULT 'REGULAR',
    RUN_DATE             DATE            NOT NULL,
    STATUS               VARCHAR2(20)    DEFAULT 'PENDING',
    TOTAL_GROSS          NUMBER(15,2),
    TOTAL_DEDUCTIONS     NUMBER(15,2),
    TOTAL_NET            NUMBER(15,2),
    TOTAL_EMPLOYER_COST  NUMBER(15,2),
    EMPLOYEE_COUNT       NUMBER(10),
    ERROR_COUNT          NUMBER(10)      DEFAULT 0,
    SUBMITTED_BY         VARCHAR2(30),
    SUBMITTED_DATE       DATE,
    APPROVED_BY          VARCHAR2(30),
    APPROVED_DATE        DATE,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_PAYROLL_RUNS PRIMARY KEY (RUN_ID),
    CONSTRAINT FK_PR_PERIOD FOREIGN KEY (PERIOD_ID) REFERENCES HRMS.PAY_PERIODS(PERIOD_ID),
    CONSTRAINT CHK_RUN_TYPE CHECK (RUN_TYPE IN ('REGULAR', 'SUPPLEMENTAL', 'BONUS', 'FINAL')),
    CONSTRAINT CHK_RUN_STATUS CHECK (STATUS IN ('PENDING', 'CALCULATING', 'CALCULATED', 'APPROVED', 'PAID', 'REVERSED', 'ERROR'))
);

-- ----------------------------------------------------------------------------
-- PAYROLL_DETAILS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.PAYROLL_DETAILS (
    DETAIL_ID            NUMBER(15)      NOT NULL,
    RUN_ID               NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    ELEMENT_ID           NUMBER(10)      NOT NULL,
    ELEMENT_TYPE         VARCHAR2(20)    NOT NULL,
    HOURS_WORKED         NUMBER(6,2),
    RATE                 NUMBER(12,4),
    AMOUNT               NUMBER(12,2)    NOT NULL,
    YTD_AMOUNT           NUMBER(15,2),
    STATUS               VARCHAR2(20)    DEFAULT 'CALCULATED',
    ERROR_MESSAGE        VARCHAR2(4000),
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_PAYROLL_DETAILS PRIMARY KEY (DETAIL_ID),
    CONSTRAINT FK_PD_RUN FOREIGN KEY (RUN_ID) REFERENCES HRMS.PAYROLL_RUNS(RUN_ID),
    CONSTRAINT FK_PD_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_PD_ELEMENT FOREIGN KEY (ELEMENT_ID) REFERENCES HRMS.PAY_ELEMENTS(ELEMENT_ID)
);

-- ----------------------------------------------------------------------------
-- TAX_BRACKETS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.TAX_BRACKETS (
    BRACKET_ID           NUMBER(10)      NOT NULL,
    TAX_YEAR             NUMBER(4)       NOT NULL,
    FILING_STATUS        VARCHAR2(30)    NOT NULL,
    BRACKET_MIN          NUMBER(12,2)    NOT NULL,
    BRACKET_MAX          NUMBER(12,2),
    TAX_RATE             NUMBER(5,4)     NOT NULL,
    BASE_TAX             NUMBER(12,2)    DEFAULT 0,
    STATE_CODE           VARCHAR2(3),
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_TAX_BRACKETS PRIMARY KEY (BRACKET_ID),
    CONSTRAINT CHK_FILING_STATUS CHECK (FILING_STATUS IN ('SINGLE', 'MARRIED_JOINT', 'MARRIED_SEPARATE', 'HEAD_OF_HOUSEHOLD'))
);

-- ----------------------------------------------------------------------------
-- EMPLOYEE_TAX_INFO
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEE_TAX_INFO (
    TAX_INFO_ID          NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    TAX_YEAR             NUMBER(4)       NOT NULL,
    FILING_STATUS        VARCHAR2(30)    NOT NULL,
    FEDERAL_ALLOWANCES   NUMBER(3)       DEFAULT 0,
    STATE_ALLOWANCES     NUMBER(3)       DEFAULT 0,
    ADDITIONAL_FED_WH    NUMBER(12,2)    DEFAULT 0,
    ADDITIONAL_STATE_WH  NUMBER(12,2)    DEFAULT 0,
    EXEMPT_FLAG          CHAR(1)         DEFAULT 'N',
    STATE_CODE           VARCHAR2(3),
    W4_RECEIVED_DATE     DATE,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMP_TAX_INFO PRIMARY KEY (TAX_INFO_ID),
    CONSTRAINT FK_ETI_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT UK_EMP_TAX_YEAR UNIQUE (EMP_ID, TAX_YEAR)
);

-- ----------------------------------------------------------------------------
-- BANK_ACCOUNTS (Direct Deposit)
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEE_BANK_ACCOUNTS (
    BANK_ACCT_ID         NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    BANK_NAME            VARCHAR2(100),
    ROUTING_NUMBER       VARCHAR2(20)    NOT NULL,
    ACCOUNT_NUMBER_ENC   VARCHAR2(200)   NOT NULL,
    ACCOUNT_TYPE         VARCHAR2(20)    DEFAULT 'CHECKING',
    DEPOSIT_TYPE         VARCHAR2(20)    DEFAULT 'FULL',
    DEPOSIT_AMOUNT       NUMBER(12,2),
    DEPOSIT_PERCENTAGE   NUMBER(5,2),
    PRIORITY_ORDER       NUMBER(2)       DEFAULT 1,
    PRENOTE_SENT         CHAR(1)         DEFAULT 'N',
    PRENOTE_DATE         DATE,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMP_BANK_ACCTS PRIMARY KEY (BANK_ACCT_ID),
    CONSTRAINT FK_BA_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_ACCT_TYPE CHECK (ACCOUNT_TYPE IN ('CHECKING', 'SAVINGS')),
    CONSTRAINT CHK_DEPOSIT_TYPE CHECK (DEPOSIT_TYPE IN ('FULL', 'PARTIAL_AMOUNT', 'PARTIAL_PERCENT', 'REMAINDER'))
);
