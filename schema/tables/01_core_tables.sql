-- ============================================================================
-- HRMS Core Tables
-- Oracle Database 19c
-- Schema: HRMS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DEPARTMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.DEPARTMENTS (
    DEPT_ID              NUMBER(10)      NOT NULL,
    DEPT_CODE            VARCHAR2(20)    NOT NULL,
    DEPT_NAME            VARCHAR2(100)   NOT NULL,
    PARENT_DEPT_ID       NUMBER(10),
    COST_CENTER          VARCHAR2(20),
    MANAGER_EMP_ID       NUMBER(10),
    LOCATION_CODE        VARCHAR2(10),
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_DEPARTMENTS PRIMARY KEY (DEPT_ID),
    CONSTRAINT UK_DEPT_CODE UNIQUE (DEPT_CODE),
    CONSTRAINT CHK_DEPT_ACTIVE CHECK (ACTIVE_FLAG IN ('Y', 'N'))
);

COMMENT ON TABLE HRMS.DEPARTMENTS IS 'Organization departments and cost centers';
COMMENT ON COLUMN HRMS.DEPARTMENTS.PARENT_DEPT_ID IS 'Self-referencing FK for department hierarchy';
COMMENT ON COLUMN HRMS.DEPARTMENTS.COST_CENTER IS 'Financial cost center code for GL integration';

-- ----------------------------------------------------------------------------
-- LOCATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.LOCATIONS (
    LOCATION_CODE        VARCHAR2(10)    NOT NULL,
    LOCATION_NAME        VARCHAR2(100)   NOT NULL,
    ADDRESS_LINE1        VARCHAR2(200),
    ADDRESS_LINE2        VARCHAR2(200),
    CITY                 VARCHAR2(100),
    STATE_PROVINCE       VARCHAR2(100),
    POSTAL_CODE          VARCHAR2(20),
    COUNTRY_CODE         VARCHAR2(3),
    PHONE_NUMBER         VARCHAR2(30),
    TIMEZONE             VARCHAR2(50)    DEFAULT 'America/New_York',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_LOCATIONS PRIMARY KEY (LOCATION_CODE)
);

-- ----------------------------------------------------------------------------
-- JOB_GRADES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.JOB_GRADES (
    GRADE_ID             NUMBER(5)       NOT NULL,
    GRADE_CODE           VARCHAR2(10)    NOT NULL,
    GRADE_NAME           VARCHAR2(50)    NOT NULL,
    MIN_SALARY           NUMBER(12,2)    NOT NULL,
    MAX_SALARY           NUMBER(12,2)    NOT NULL,
    OVERTIME_ELIGIBLE    CHAR(1)         DEFAULT 'N',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_JOB_GRADES PRIMARY KEY (GRADE_ID),
    CONSTRAINT UK_GRADE_CODE UNIQUE (GRADE_CODE),
    CONSTRAINT CHK_SALARY_RANGE CHECK (MAX_SALARY >= MIN_SALARY)
);

-- ----------------------------------------------------------------------------
-- JOB_TITLES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.JOB_TITLES (
    JOB_ID               NUMBER(10)      NOT NULL,
    JOB_CODE             VARCHAR2(20)    NOT NULL,
    JOB_TITLE            VARCHAR2(100)   NOT NULL,
    JOB_FAMILY           VARCHAR2(50),
    GRADE_ID             NUMBER(5)       NOT NULL,
    EEO_CATEGORY         VARCHAR2(10),
    FLSA_STATUS          VARCHAR2(10)    DEFAULT 'EXEMPT',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_JOB_TITLES PRIMARY KEY (JOB_ID),
    CONSTRAINT UK_JOB_CODE UNIQUE (JOB_CODE),
    CONSTRAINT FK_JOB_GRADE FOREIGN KEY (GRADE_ID) REFERENCES HRMS.JOB_GRADES(GRADE_ID)
);

-- ----------------------------------------------------------------------------
-- EMPLOYEES
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEES (
    EMP_ID               NUMBER(10)      NOT NULL,
    EMP_NUMBER           VARCHAR2(20)    NOT NULL,
    FIRST_NAME           VARCHAR2(50)    NOT NULL,
    MIDDLE_NAME          VARCHAR2(50),
    LAST_NAME            VARCHAR2(50)    NOT NULL,
    DATE_OF_BIRTH        DATE,
    GENDER               CHAR(1),
    MARITAL_STATUS       VARCHAR2(10),
    NATIONALITY          VARCHAR2(50),
    SSN_ENCRYPTED        VARCHAR2(200),
    EMAIL                VARCHAR2(100),
    PHONE_WORK           VARCHAR2(30),
    PHONE_MOBILE         VARCHAR2(30),
    ADDRESS_LINE1        VARCHAR2(200),
    ADDRESS_LINE2        VARCHAR2(200),
    CITY                 VARCHAR2(100),
    STATE_PROVINCE       VARCHAR2(100),
    POSTAL_CODE          VARCHAR2(20),
    COUNTRY_CODE         VARCHAR2(3),
    HIRE_DATE            DATE            NOT NULL,
    TERMINATION_DATE     DATE,
    TERMINATION_REASON   VARCHAR2(50),
    DEPT_ID              NUMBER(10)      NOT NULL,
    JOB_ID               NUMBER(10)      NOT NULL,
    MANAGER_EMP_ID       NUMBER(10),
    LOCATION_CODE        VARCHAR2(10),
    EMPLOYMENT_TYPE      VARCHAR2(20)    DEFAULT 'FULL_TIME',
    EMPLOYMENT_STATUS    VARCHAR2(20)    DEFAULT 'ACTIVE',
    PHOTO_BLOB           BLOB,
    NOTES                CLOB,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMPLOYEES PRIMARY KEY (EMP_ID),
    CONSTRAINT UK_EMP_NUMBER UNIQUE (EMP_NUMBER),
    CONSTRAINT FK_EMP_DEPT FOREIGN KEY (DEPT_ID) REFERENCES HRMS.DEPARTMENTS(DEPT_ID),
    CONSTRAINT FK_EMP_JOB FOREIGN KEY (JOB_ID) REFERENCES HRMS.JOB_TITLES(JOB_ID),
    CONSTRAINT FK_EMP_MANAGER FOREIGN KEY (MANAGER_EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT FK_EMP_LOCATION FOREIGN KEY (LOCATION_CODE) REFERENCES HRMS.LOCATIONS(LOCATION_CODE),
    CONSTRAINT CHK_EMP_STATUS CHECK (EMPLOYMENT_STATUS IN ('ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'TERMINATED')),
    CONSTRAINT CHK_EMP_TYPE CHECK (EMPLOYMENT_TYPE IN ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'INTERN')),
    CONSTRAINT CHK_EMP_GENDER CHECK (GENDER IN ('M', 'F', 'O'))
);

COMMENT ON TABLE HRMS.EMPLOYEES IS 'Master employee records - core entity of the HRMS system';
COMMENT ON COLUMN HRMS.EMPLOYEES.SSN_ENCRYPTED IS 'AES-256 encrypted SSN - decrypted only in PKG_SECURITY';
COMMENT ON COLUMN HRMS.EMPLOYEES.EMPLOYMENT_STATUS IS 'Current status: ACTIVE, ON_LEAVE, SUSPENDED, TERMINATED';

-- ----------------------------------------------------------------------------
-- EMPLOYEE_HISTORY
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEE_HISTORY (
    HIST_ID              NUMBER(15)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    CHANGE_TYPE          VARCHAR2(30)    NOT NULL,
    EFFECTIVE_DATE       DATE            NOT NULL,
    OLD_DEPT_ID          NUMBER(10),
    NEW_DEPT_ID          NUMBER(10),
    OLD_JOB_ID           NUMBER(10),
    NEW_JOB_ID           NUMBER(10),
    OLD_MANAGER_ID       NUMBER(10),
    NEW_MANAGER_ID       NUMBER(10),
    OLD_SALARY           NUMBER(12,2),
    NEW_SALARY           NUMBER(12,2),
    OLD_LOCATION         VARCHAR2(10),
    NEW_LOCATION         VARCHAR2(10),
    REASON_CODE          VARCHAR2(30),
    COMMENTS             VARCHAR2(4000),
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT PK_EMP_HISTORY PRIMARY KEY (HIST_ID),
    CONSTRAINT FK_HIST_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_CHANGE_TYPE CHECK (CHANGE_TYPE IN (
        'HIRE', 'TRANSFER', 'PROMOTION', 'DEMOTION', 'SALARY_CHANGE',
        'TERMINATION', 'REHIRE', 'LEAVE_START', 'LEAVE_END', 'STATUS_CHANGE'
    ))
);

-- ----------------------------------------------------------------------------
-- EMPLOYEE_DEPENDENTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMPLOYEE_DEPENDENTS (
    DEPENDENT_ID         NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    FIRST_NAME           VARCHAR2(50)    NOT NULL,
    LAST_NAME            VARCHAR2(50)    NOT NULL,
    RELATIONSHIP         VARCHAR2(20)    NOT NULL,
    DATE_OF_BIRTH        DATE,
    SSN_ENCRYPTED        VARCHAR2(200),
    BENEFITS_ENROLLED    CHAR(1)         DEFAULT 'N',
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMP_DEPENDENTS PRIMARY KEY (DEPENDENT_ID),
    CONSTRAINT FK_DEP_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID),
    CONSTRAINT CHK_RELATIONSHIP CHECK (RELATIONSHIP IN ('SPOUSE', 'CHILD', 'PARENT', 'DOMESTIC_PARTNER', 'OTHER'))
);

-- ----------------------------------------------------------------------------
-- EMERGENCY_CONTACTS
-- ----------------------------------------------------------------------------
CREATE TABLE HRMS.EMERGENCY_CONTACTS (
    CONTACT_ID           NUMBER(10)      NOT NULL,
    EMP_ID               NUMBER(10)      NOT NULL,
    CONTACT_NAME         VARCHAR2(100)   NOT NULL,
    RELATIONSHIP         VARCHAR2(30),
    PHONE_PRIMARY        VARCHAR2(30)    NOT NULL,
    PHONE_SECONDARY      VARCHAR2(30),
    EMAIL                VARCHAR2(100),
    PRIORITY_ORDER       NUMBER(2)       DEFAULT 1,
    ACTIVE_FLAG          CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY           VARCHAR2(30)    NOT NULL,
    CREATED_DATE         DATE            DEFAULT SYSDATE NOT NULL,
    MODIFIED_BY          VARCHAR2(30),
    MODIFIED_DATE        DATE,
    CONSTRAINT PK_EMERGENCY_CONTACTS PRIMARY KEY (CONTACT_ID),
    CONSTRAINT FK_EC_EMP FOREIGN KEY (EMP_ID) REFERENCES HRMS.EMPLOYEES(EMP_ID)
);
