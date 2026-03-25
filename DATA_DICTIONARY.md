# Data Dictionary

> **HRMS Legacy Oracle Forms / PL/SQL Estate**
> Extracted from DDL schemas in `schema/tables/`, `schema/views/`, `schema/sequences/`, and `data/seed/`.

---

## 1. Domain Overview

| Domain | Tables | Description |
|---|---|---|
| **Core HR** | 8 | Organization structure, employee master data, dependents, contacts, change history |
| **Payroll** | 9 | Salary records, pay elements, pay periods, payroll runs, tax info, bank accounts |
| **Leave Management** | 5 | Leave types, balances, requests, accrual logs, holidays |
| **Performance** | 3 | Review cycles, performance reviews, goals |
| **System** | 5 | Audit log, configuration, notifications, sessions, lookups |
| **Total** | **30** | |

---

## 2. Core HR Domain

### 2.1 DEPARTMENTS

> Organization departments and cost centers. Self-referencing hierarchy via `PARENT_DEPT_ID`.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `DEPT_ID` | NUMBER(10) | NOT NULL | - | Primary key (surrogate) |
| `DEPT_CODE` | VARCHAR2(20) | NOT NULL | - | Unique business code (e.g., `HR`, `FIN`, `IT`) |
| `DEPT_NAME` | VARCHAR2(100) | NOT NULL | - | Display name |
| `PARENT_DEPT_ID` | NUMBER(10) | NULL | - | Self-referencing FK for department hierarchy |
| `COST_CENTER` | VARCHAR2(20) | NULL | - | Financial cost center code for GL integration |
| `MANAGER_EMP_ID` | NUMBER(10) | NULL | - | FK to `EMPLOYEES` (department head) |
| `LOCATION_CODE` | VARCHAR2(10) | NULL | - | FK to `LOCATIONS` |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag (`Y`/`N`) |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit: creating user |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit: creation timestamp |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit: last modifier |
| `MODIFIED_DATE` | DATE | NULL | - | Audit: last modification timestamp |

**Constraints**: PK(`DEPT_ID`), UK(`DEPT_CODE`), CHECK(`ACTIVE_FLAG IN ('Y','N')`)
**Seed Data**: 10 departments (Executive, HR, Finance, IT, IT-Dev, IT-Ops, Sales, Marketing, Operations, Legal)

---

### 2.2 LOCATIONS

> Physical office locations.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `LOCATION_CODE` | VARCHAR2(10) | NOT NULL | - | Primary key (natural key) |
| `LOCATION_NAME` | VARCHAR2(100) | NOT NULL | - | Display name |
| `ADDRESS_LINE1` | VARCHAR2(200) | NULL | - | Street address |
| `ADDRESS_LINE2` | VARCHAR2(200) | NULL | - | Suite/floor |
| `CITY` | VARCHAR2(100) | NULL | - | City |
| `STATE_PROVINCE` | VARCHAR2(100) | NULL | - | State/province |
| `POSTAL_CODE` | VARCHAR2(20) | NULL | - | ZIP/postal code |
| `COUNTRY_CODE` | VARCHAR2(3) | NULL | - | ISO country code |
| `PHONE_NUMBER` | VARCHAR2(30) | NULL | - | Main phone |
| `TIMEZONE` | VARCHAR2(50) | NULL | `'America/New_York'` | IANA timezone |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`LOCATION_CODE`)
**Seed Data**: 3 locations (HQ New York, Chicago, San Francisco)

---

### 2.3 JOB_GRADES

> Compensation bands with salary ranges.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `GRADE_ID` | NUMBER(5) | NOT NULL | - | Primary key |
| `GRADE_CODE` | VARCHAR2(10) | NOT NULL | - | Unique code |
| `GRADE_NAME` | VARCHAR2(50) | NOT NULL | - | Display name (e.g., `Entry Level`, `Senior`, `C-Suite`) |
| `MIN_SALARY` | NUMBER(12,2) | NOT NULL | - | Minimum salary for grade |
| `MAX_SALARY` | NUMBER(12,2) | NOT NULL | - | Maximum salary for grade |
| `OVERTIME_ELIGIBLE` | CHAR(1) | NULL | `'N'` | FLSA overtime eligibility |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`GRADE_ID`), UK(`GRADE_CODE`), CHECK(`MAX_SALARY >= MIN_SALARY`)
**Seed Data**: 10 grades ($35K-$600K range)

---

### 2.4 JOB_TITLES

> Job positions linked to grades for compensation governance.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `JOB_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `JOB_CODE` | VARCHAR2(20) | NOT NULL | - | Unique code (e.g., `CEO`, `SR-DEV`, `HR-SPEC`) |
| `JOB_TITLE` | VARCHAR2(100) | NOT NULL | - | Display title |
| `JOB_FAMILY` | VARCHAR2(50) | NULL | - | Job family grouping |
| `GRADE_ID` | NUMBER(5) | NOT NULL | - | FK to `JOB_GRADES` |
| `EEO_CATEGORY` | VARCHAR2(10) | NULL | - | EEO-1 reporting category |
| `FLSA_STATUS` | VARCHAR2(10) | NULL | `'EXEMPT'` | Fair Labor Standards Act status |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`JOB_ID`), UK(`JOB_CODE`), FK(`GRADE_ID` -> `JOB_GRADES`)
**Seed Data**: 26 job titles across all departments

---

### 2.5 EMPLOYEES

> Master employee records - central entity of the HRMS system.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `EMP_ID` | NUMBER(10) | NOT NULL | - | Primary key (surrogate, from `SEQ_EMPLOYEE`) |
| `EMP_NUMBER` | VARCHAR2(20) | NOT NULL | - | Business key (format: `EMP-XXXXXX`) |
| `FIRST_NAME` | VARCHAR2(50) | NOT NULL | - | Legal first name |
| `MIDDLE_NAME` | VARCHAR2(50) | NULL | - | Middle name |
| `LAST_NAME` | VARCHAR2(50) | NOT NULL | - | Legal last name |
| `DATE_OF_BIRTH` | DATE | NULL | - | Birth date |
| `GENDER` | CHAR(1) | NULL | - | `M`, `F`, or `O` |
| `MARITAL_STATUS` | VARCHAR2(10) | NULL | - | Marital status |
| `NATIONALITY` | VARCHAR2(50) | NULL | - | Nationality |
| `SSN_ENCRYPTED` | VARCHAR2(200) | NULL | - | AES-256 encrypted SSN (decrypted in `PKG_SECURITY`) |
| `EMAIL` | VARCHAR2(100) | NULL | - | Work email |
| `PHONE_WORK` | VARCHAR2(30) | NULL | - | Work phone |
| `PHONE_MOBILE` | VARCHAR2(30) | NULL | - | Mobile phone |
| `ADDRESS_LINE1` | VARCHAR2(200) | NULL | - | Home address |
| `ADDRESS_LINE2` | VARCHAR2(200) | NULL | - | Suite/apartment |
| `CITY` | VARCHAR2(100) | NULL | - | City |
| `STATE_PROVINCE` | VARCHAR2(100) | NULL | - | State/province |
| `POSTAL_CODE` | VARCHAR2(20) | NULL | - | ZIP/postal code |
| `COUNTRY_CODE` | VARCHAR2(3) | NULL | - | ISO country code |
| `HIRE_DATE` | DATE | NOT NULL | - | Original hire date |
| `TERMINATION_DATE` | DATE | NULL | - | Date of termination (if applicable) |
| `TERMINATION_REASON` | VARCHAR2(50) | NULL | - | Reason code (e.g., `VOLUNTARY`) |
| `DEPT_ID` | NUMBER(10) | NOT NULL | - | FK to `DEPARTMENTS` |
| `JOB_ID` | NUMBER(10) | NOT NULL | - | FK to `JOB_TITLES` |
| `MANAGER_EMP_ID` | NUMBER(10) | NULL | - | Self-referencing FK (reporting manager) |
| `LOCATION_CODE` | VARCHAR2(10) | NULL | - | FK to `LOCATIONS` |
| `EMPLOYMENT_TYPE` | VARCHAR2(20) | NULL | `'FULL_TIME'` | `FULL_TIME`, `PART_TIME`, `CONTRACT`, `INTERN` |
| `EMPLOYMENT_STATUS` | VARCHAR2(20) | NULL | `'ACTIVE'` | `ACTIVE`, `ON_LEAVE`, `SUSPENDED`, `TERMINATED` |
| `PHOTO_BLOB` | BLOB | NULL | - | Employee photo |
| `NOTES` | CLOB | NULL | - | Free-text notes |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`EMP_ID`), UK(`EMP_NUMBER`), FKs to `DEPARTMENTS`, `JOB_TITLES`, `LOCATIONS`, self-ref `EMPLOYEES`, CHECK on status/type/gender
**Triggers**: `TRG_EMP_BEFORE_INSERT`, `TRG_EMP_BEFORE_UPDATE`, `TRG_EMP_INSTEAD_OF_DELETE`
**Seed Data**: 25 employees

---

### 2.6 EMPLOYEE_HISTORY

> Change tracking for employee lifecycle events.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `HIST_ID` | NUMBER(15) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `CHANGE_TYPE` | VARCHAR2(30) | NOT NULL | - | `HIRE`, `TRANSFER`, `PROMOTION`, `DEMOTION`, `SALARY_CHANGE`, `TERMINATION`, `REHIRE`, `LEAVE_START`, `LEAVE_END`, `STATUS_CHANGE` |
| `EFFECTIVE_DATE` | DATE | NOT NULL | - | When the change took effect |
| `OLD_DEPT_ID` | NUMBER(10) | NULL | - | Previous department |
| `NEW_DEPT_ID` | NUMBER(10) | NULL | - | New department |
| `OLD_JOB_ID` | NUMBER(10) | NULL | - | Previous job |
| `NEW_JOB_ID` | NUMBER(10) | NULL | - | New job |
| `OLD_MANAGER_ID` | NUMBER(10) | NULL | - | Previous manager |
| `NEW_MANAGER_ID` | NUMBER(10) | NULL | - | New manager |
| `OLD_SALARY` | NUMBER(12,2) | NULL | - | Previous salary |
| `NEW_SALARY` | NUMBER(12,2) | NULL | - | New salary |
| `OLD_LOCATION` | VARCHAR2(10) | NULL | - | Previous location |
| `NEW_LOCATION` | VARCHAR2(10) | NULL | - | New location |
| `REASON_CODE` | VARCHAR2(30) | NULL | - | Reason classification |
| `COMMENTS` | VARCHAR2(4000) | NULL | - | Free text |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`HIST_ID`), FK(`EMP_ID` -> `EMPLOYEES`), CHECK on `CHANGE_TYPE`

---

### 2.7 EMPLOYEE_DEPENDENTS

> Employee dependents for benefits enrollment.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `DEPENDENT_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `FIRST_NAME` | VARCHAR2(50) | NOT NULL | - | Dependent first name |
| `LAST_NAME` | VARCHAR2(50) | NOT NULL | - | Dependent last name |
| `RELATIONSHIP` | VARCHAR2(20) | NOT NULL | - | `SPOUSE`, `CHILD`, `PARENT`, `DOMESTIC_PARTNER`, `OTHER` |
| `DATE_OF_BIRTH` | DATE | NULL | - | Birth date |
| `SSN_ENCRYPTED` | VARCHAR2(200) | NULL | - | Encrypted SSN |
| `BENEFITS_ENROLLED` | CHAR(1) | NULL | `'N'` | Benefits enrollment flag |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`DEPENDENT_ID`), FK(`EMP_ID` -> `EMPLOYEES`), CHECK on `RELATIONSHIP`

---

### 2.8 EMERGENCY_CONTACTS

> Employee emergency contact information.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `CONTACT_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `CONTACT_NAME` | VARCHAR2(100) | NOT NULL | - | Contact full name |
| `RELATIONSHIP` | VARCHAR2(30) | NULL | - | Relationship to employee |
| `PHONE_PRIMARY` | VARCHAR2(30) | NOT NULL | - | Primary phone |
| `PHONE_SECONDARY` | VARCHAR2(30) | NULL | - | Alternate phone |
| `EMAIL` | VARCHAR2(100) | NULL | - | Email |
| `PRIORITY_ORDER` | NUMBER(2) | NULL | `1` | Contact priority |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`CONTACT_ID`), FK(`EMP_ID` -> `EMPLOYEES`)

---

## 3. Payroll Domain

### 3.1 SALARY_RECORDS

> Employee salary history with effective dating.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `SALARY_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `EFFECTIVE_DATE` | DATE | NOT NULL | - | Start date of this salary |
| `END_DATE` | DATE | NULL | - | End date (NULL = current) |
| `BASE_SALARY` | NUMBER(12,2) | NOT NULL | - | Annual/hourly rate |
| `CURRENCY_CODE` | VARCHAR2(3) | NULL | `'USD'` | ISO currency |
| `PAY_FREQUENCY` | VARCHAR2(20) | NULL | `'MONTHLY'` | `WEEKLY`, `BIWEEKLY`, `SEMIMONTHLY`, `MONTHLY` |
| `SALARY_BASIS` | VARCHAR2(20) | NULL | `'ANNUAL'` | `ANNUAL` or `HOURLY` |
| `CHANGE_REASON` | VARCHAR2(50) | NULL | - | Reason for change |
| `CHANGE_PCT` | NUMBER(5,2) | NULL | - | Percentage change from previous |
| `APPROVED_BY` | NUMBER(10) | NULL | - | Approver employee ID |
| `APPROVAL_DATE` | DATE | NULL | - | Date approved |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Current record flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`SALARY_ID`), FK(`EMP_ID` -> `EMPLOYEES`), CHECK on `PAY_FREQUENCY`, `SALARY_BASIS`
**Triggers**: `TRG_SALARY_AUDIT` (logs all changes)

---

### 3.2 PAY_ELEMENTS

> Catalog of earning/deduction/tax/benefit types.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `ELEMENT_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `ELEMENT_CODE` | VARCHAR2(30) | NOT NULL | - | Unique code |
| `ELEMENT_NAME` | VARCHAR2(100) | NOT NULL | - | Display name |
| `ELEMENT_TYPE` | VARCHAR2(20) | NOT NULL | - | `EARNING`, `DEDUCTION`, `TAX`, `BENEFIT`, `REIMBURSEMENT` |
| `CALCULATION_TYPE` | VARCHAR2(20) | NOT NULL | - | `FLAT`, `PERCENTAGE`, `HOURS`, `FORMULA` |
| `DEFAULT_AMOUNT` | NUMBER(12,2) | NULL | - | Default flat amount |
| `DEFAULT_PERCENTAGE` | NUMBER(5,2) | NULL | - | Default percentage |
| `TAXABLE_FLAG` | CHAR(1) | NULL | `'Y'` | Subject to taxation |
| `PRETAX_FLAG` | CHAR(1) | NULL | `'N'` | Pre-tax deduction |
| `EMPLOYER_PAID` | CHAR(1) | NULL | `'N'` | Employer-paid benefit |
| `GL_ACCOUNT_CODE` | VARCHAR2(30) | NULL | - | GL account for integration |
| `PRIORITY_ORDER` | NUMBER(5) | NULL | `100` | Calculation priority |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`ELEMENT_ID`), UK(`ELEMENT_CODE`), CHECK on `ELEMENT_TYPE`, `CALCULATION_TYPE`

---

### 3.3 EMPLOYEE_PAY_ELEMENTS

> Per-employee overrides and enrollments for pay elements.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `EMP_ELEMENT_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `ELEMENT_ID` | NUMBER(10) | NOT NULL | - | FK to `PAY_ELEMENTS` |
| `EFFECTIVE_DATE` | DATE | NOT NULL | - | Start date |
| `END_DATE` | DATE | NULL | - | End date |
| `AMOUNT` | NUMBER(12,2) | NULL | - | Override amount |
| `PERCENTAGE` | NUMBER(5,2) | NULL | - | Override percentage |
| `OVERRIDE_AMOUNT` | NUMBER(12,2) | NULL | - | Hard override (takes precedence) |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`EMP_ELEMENT_ID`), FK to `EMPLOYEES`, `PAY_ELEMENTS`

---

### 3.4 PAY_PERIODS

> Payroll period definitions.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `PERIOD_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `PERIOD_NAME` | VARCHAR2(50) | NOT NULL | - | Display name (e.g., `January 2024`) |
| `PAY_FREQUENCY` | VARCHAR2(20) | NOT NULL | - | Frequency type |
| `PERIOD_START_DATE` | DATE | NOT NULL | - | Period start |
| `PERIOD_END_DATE` | DATE | NOT NULL | - | Period end |
| `PAY_DATE` | DATE | NOT NULL | - | Scheduled pay date |
| `STATUS` | VARCHAR2(20) | NULL | `'OPEN'` | `OPEN`, `PROCESSING`, `CLOSED`, `REVERSED` |
| `CLOSED_BY` | VARCHAR2(30) | NULL | - | Who closed the period |
| `CLOSED_DATE` | DATE | NULL | - | When closed |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`PERIOD_ID`), CHECK on `STATUS`

---

### 3.5 PAYROLL_RUNS

> Individual payroll run executions within a pay period.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `RUN_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `PERIOD_ID` | NUMBER(10) | NOT NULL | - | FK to `PAY_PERIODS` |
| `RUN_TYPE` | VARCHAR2(20) | NULL | `'REGULAR'` | `REGULAR`, `SUPPLEMENTAL`, `BONUS`, `FINAL` |
| `RUN_DATE` | DATE | NOT NULL | - | Execution date |
| `STATUS` | VARCHAR2(20) | NULL | `'PENDING'` | `PENDING`, `CALCULATING`, `CALCULATED`, `APPROVED`, `PAID`, `REVERSED`, `ERROR` |
| `TOTAL_GROSS` | NUMBER(15,2) | NULL | - | Sum of all gross pay |
| `TOTAL_DEDUCTIONS` | NUMBER(15,2) | NULL | - | Sum of all deductions |
| `TOTAL_NET` | NUMBER(15,2) | NULL | - | Net pay total |
| `TOTAL_EMPLOYER_COST` | NUMBER(15,2) | NULL | - | Total employer cost |
| `EMPLOYEE_COUNT` | NUMBER(10) | NULL | - | Employees processed |
| `ERROR_COUNT` | NUMBER(10) | NULL | `0` | Errors encountered |
| `SUBMITTED_BY` | VARCHAR2(30) | NULL | - | Submitter |
| `SUBMITTED_DATE` | DATE | NULL | - | Submission date |
| `APPROVED_BY` | VARCHAR2(30) | NULL | - | Approver |
| `APPROVED_DATE` | DATE | NULL | - | Approval date |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`RUN_ID`), FK(`PERIOD_ID` -> `PAY_PERIODS`), CHECK on `RUN_TYPE`, `STATUS`

---

### 3.6 PAYROLL_DETAILS

> Line-item payroll calculations per employee per run.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `DETAIL_ID` | NUMBER(15) | NOT NULL | - | Primary key |
| `RUN_ID` | NUMBER(10) | NOT NULL | - | FK to `PAYROLL_RUNS` |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `ELEMENT_ID` | NUMBER(10) | NOT NULL | - | FK to `PAY_ELEMENTS` |
| `ELEMENT_TYPE` | VARCHAR2(20) | NOT NULL | - | Denormalized element type |
| `HOURS_WORKED` | NUMBER(6,2) | NULL | - | Hours (for hourly employees) |
| `RATE` | NUMBER(12,4) | NULL | - | Hourly rate |
| `AMOUNT` | NUMBER(12,2) | NOT NULL | - | Calculated amount (negative for deductions) |
| `YTD_AMOUNT` | NUMBER(15,2) | NULL | - | Year-to-date running total |
| `STATUS` | VARCHAR2(20) | NULL | `'CALCULATED'` | Line status |
| `ERROR_MESSAGE` | VARCHAR2(4000) | NULL | - | Error detail if status = ERROR |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`DETAIL_ID`), FKs to `PAYROLL_RUNS`, `EMPLOYEES`, `PAY_ELEMENTS`

---

### 3.7 TAX_BRACKETS

> Federal and state tax bracket definitions by year and filing status.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `BRACKET_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `TAX_YEAR` | NUMBER(4) | NOT NULL | - | Tax year |
| `FILING_STATUS` | VARCHAR2(30) | NOT NULL | - | `SINGLE`, `MARRIED_JOINT`, `MARRIED_SEPARATE`, `HEAD_OF_HOUSEHOLD` |
| `BRACKET_MIN` | NUMBER(12,2) | NOT NULL | - | Bracket lower bound |
| `BRACKET_MAX` | NUMBER(12,2) | NULL | - | Bracket upper bound (NULL = unlimited) |
| `TAX_RATE` | NUMBER(5,4) | NOT NULL | - | Marginal tax rate |
| `BASE_TAX` | NUMBER(12,2) | NULL | `0` | Cumulative base tax |
| `STATE_CODE` | VARCHAR2(3) | NULL | - | NULL = federal, otherwise state code |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`BRACKET_ID`), CHECK on `FILING_STATUS`
**Note**: Table exists but `PKG_PAYROLL.calculate_federal_tax` uses hard-coded 2024 brackets instead

---

### 3.8 EMPLOYEE_TAX_INFO

> Per-employee, per-year tax withholding elections.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `TAX_INFO_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `TAX_YEAR` | NUMBER(4) | NOT NULL | - | Tax year |
| `FILING_STATUS` | VARCHAR2(30) | NOT NULL | - | Filing status |
| `FEDERAL_ALLOWANCES` | NUMBER(3) | NULL | `0` | W-4 allowances |
| `STATE_ALLOWANCES` | NUMBER(3) | NULL | `0` | State allowances |
| `ADDITIONAL_FED_WH` | NUMBER(12,2) | NULL | `0` | Extra federal withholding |
| `ADDITIONAL_STATE_WH` | NUMBER(12,2) | NULL | `0` | Extra state withholding |
| `EXEMPT_FLAG` | CHAR(1) | NULL | `'N'` | Tax-exempt |
| `STATE_CODE` | VARCHAR2(3) | NULL | - | State of residence |
| `W4_RECEIVED_DATE` | DATE | NULL | - | W-4 form receipt date |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`TAX_INFO_ID`), FK(`EMP_ID` -> `EMPLOYEES`), UK(`EMP_ID`, `TAX_YEAR`)

---

### 3.9 EMPLOYEE_BANK_ACCOUNTS

> Direct deposit banking details.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `BANK_ACCT_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `BANK_NAME` | VARCHAR2(100) | NULL | - | Bank name |
| `ROUTING_NUMBER` | VARCHAR2(20) | NOT NULL | - | ABA routing number |
| `ACCOUNT_NUMBER_ENC` | VARCHAR2(200) | NOT NULL | - | Encrypted account number |
| `ACCOUNT_TYPE` | VARCHAR2(20) | NULL | `'CHECKING'` | `CHECKING` or `SAVINGS` |
| `DEPOSIT_TYPE` | VARCHAR2(20) | NULL | `'FULL'` | `FULL`, `PARTIAL_AMOUNT`, `PARTIAL_PERCENT`, `REMAINDER` |
| `DEPOSIT_AMOUNT` | NUMBER(12,2) | NULL | - | Fixed deposit amount |
| `DEPOSIT_PERCENTAGE` | NUMBER(5,2) | NULL | - | Percentage deposit |
| `PRIORITY_ORDER` | NUMBER(2) | NULL | `1` | Split deposit priority |
| `PRENOTE_SENT` | CHAR(1) | NULL | `'N'` | Pre-notification sent |
| `PRENOTE_DATE` | DATE | NULL | - | Pre-notification date |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`BANK_ACCT_ID`), FK(`EMP_ID` -> `EMPLOYEES`), CHECK on `ACCOUNT_TYPE`, `DEPOSIT_TYPE`

---

## 4. Leave Management Domain

### 4.1 LEAVE_TYPES

> Configuration of available leave categories.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `LEAVE_TYPE_ID` | NUMBER(5) | NOT NULL | - | Primary key |
| `LEAVE_TYPE_CODE` | VARCHAR2(20) | NOT NULL | - | Unique code (e.g., `PTO`, `SICK`, `FMLA`) |
| `LEAVE_TYPE_NAME` | VARCHAR2(50) | NOT NULL | - | Display name |
| `PAID_FLAG` | CHAR(1) | NULL | `'Y'` | Paid leave |
| `ACCRUAL_FLAG` | CHAR(1) | NULL | `'Y'` | Subject to accrual |
| `ACCRUAL_RATE` | NUMBER(6,2) | NULL | - | Days accrued per period |
| `ACCRUAL_FREQUENCY` | VARCHAR2(20) | NULL | - | `MONTHLY`, `BIWEEKLY`, `ANNUAL` |
| `MAX_BALANCE` | NUMBER(6,2) | NULL | - | Maximum carryable balance |
| `CARRYOVER_MAX` | NUMBER(6,2) | NULL | - | Max days to carry over |
| `CARRYOVER_EXPIRY` | NUMBER(3) | NULL | - | Months until carryover expires |
| `MIN_TENURE_DAYS` | NUMBER(5) | NULL | `0` | Minimum tenure to be eligible |
| `REQUIRES_APPROVAL` | CHAR(1) | NULL | `'Y'` | Manager approval required |
| `REQUIRES_DOCUMENT` | CHAR(1) | NULL | `'N'` | Supporting document required |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`LEAVE_TYPE_ID`), UK(`LEAVE_TYPE_CODE`), CHECK on `ACCRUAL_FREQUENCY`
**Seed Data**: 6 leave types (PTO, Sick, Comp, FMLA, Jury, Bereavement)

---

### 4.2 LEAVE_BALANCES

> Per-employee, per-year leave balance tracking.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `BALANCE_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `LEAVE_TYPE_ID` | NUMBER(5) | NOT NULL | - | FK to `LEAVE_TYPES` |
| `CALENDAR_YEAR` | NUMBER(4) | NOT NULL | - | Year |
| `OPENING_BALANCE` | NUMBER(6,2) | NULL | `0` | Start-of-year balance |
| `ACCRUED` | NUMBER(6,2) | NULL | `0` | Accrued during year |
| `USED` | NUMBER(6,2) | NULL | `0` | Used during year |
| `ADJUSTMENT` | NUMBER(6,2) | NULL | `0` | Manual adjustments |
| `PENDING` | NUMBER(6,2) | NULL | `0` | Pending request days |
| `AVAILABLE` | NUMBER(6,2) | VIRTUAL | - | **Virtual column**: `OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT - PENDING` |
| `CARRYOVER_FROM_PREV` | NUMBER(6,2) | NULL | `0` | Days carried from previous year |
| `CARRYOVER_EXPIRY_DT` | DATE | NULL | - | When carryover expires |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`BALANCE_ID`), FKs to `EMPLOYEES`, `LEAVE_TYPES`, UK(`EMP_ID`, `LEAVE_TYPE_ID`, `CALENDAR_YEAR`)

---

### 4.3 LEAVE_REQUESTS

> Individual leave request records.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `REQUEST_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` (requester) |
| `LEAVE_TYPE_ID` | NUMBER(5) | NOT NULL | - | FK to `LEAVE_TYPES` |
| `START_DATE` | DATE | NOT NULL | - | Leave start |
| `END_DATE` | DATE | NOT NULL | - | Leave end |
| `TOTAL_DAYS` | NUMBER(5,1) | NOT NULL | - | Total leave days (supports 0.5 for half-day) |
| `HALF_DAY_FLAG` | CHAR(1) | NULL | `'N'` | Half-day request |
| `HALF_DAY_PERIOD` | VARCHAR2(10) | NULL | - | `AM` or `PM` |
| `STATUS` | VARCHAR2(20) | NULL | `'PENDING'` | `PENDING`, `APPROVED`, `REJECTED`, `CANCELLED`, `TAKEN` |
| `REASON` | VARCHAR2(4000) | NULL | - | Reason for leave |
| `SUPPORTING_DOC_PATH` | VARCHAR2(500) | NULL | - | Document file path |
| `APPROVER_EMP_ID` | NUMBER(10) | NULL | - | FK to `EMPLOYEES` (approver) |
| `APPROVAL_DATE` | DATE | NULL | - | When approved/rejected |
| `APPROVAL_COMMENTS` | VARCHAR2(4000) | NULL | - | Approver comments |
| `CANCEL_REASON` | VARCHAR2(4000) | NULL | - | Cancellation reason |
| `CANCELLED_DATE` | DATE | NULL | - | When cancelled |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`REQUEST_ID`), FKs to `EMPLOYEES` (x2), `LEAVE_TYPES`, CHECK on `STATUS`, `END_DATE >= START_DATE`, `HALF_DAY_PERIOD`
**Triggers**: `TRG_LEAVE_REQUEST_AUDIT`

---

### 4.4 LEAVE_ACCRUAL_LOG

> Audit trail for monthly accrual batch runs.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `ACCRUAL_ID` | NUMBER(15) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `LEAVE_TYPE_ID` | NUMBER(5) | NOT NULL | - | FK to `LEAVE_TYPES` |
| `ACCRUAL_DATE` | DATE | NOT NULL | - | Date of accrual |
| `ACCRUAL_AMOUNT` | NUMBER(6,2) | NOT NULL | - | Days accrued |
| `BALANCE_AFTER` | NUMBER(6,2) | NULL | - | Balance after accrual |
| `RUN_ID` | NUMBER(10) | NULL | - | Batch run reference |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`ACCRUAL_ID`), FKs to `EMPLOYEES`, `LEAVE_TYPES`

---

### 4.5 HOLIDAYS

> Company-observed holiday calendar.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `HOLIDAY_ID` | NUMBER(5) | NOT NULL | - | Primary key |
| `HOLIDAY_DATE` | DATE | NOT NULL | - | Holiday date |
| `HOLIDAY_NAME` | VARCHAR2(100) | NOT NULL | - | Display name |
| `LOCATION_CODE` | VARCHAR2(10) | NULL | - | Location-specific (NULL = all) |
| `FLOATING_FLAG` | CHAR(1) | NULL | `'N'` | Floating holiday |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`HOLIDAY_ID`)
**Seed Data**: 10 US federal holidays for 2024

---

## 5. Performance Domain

### 5.1 REVIEW_CYCLES

> Annual/periodic performance review cycle definitions.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `CYCLE_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `CYCLE_NAME` | VARCHAR2(100) | NOT NULL | - | Display name |
| `CYCLE_YEAR` | NUMBER(4) | NOT NULL | - | Year |
| `START_DATE` | DATE | NOT NULL | - | Cycle start |
| `END_DATE` | DATE | NOT NULL | - | Cycle end |
| `SELF_REVIEW_DUE` | DATE | NULL | - | Self-review deadline |
| `MANAGER_REVIEW_DUE` | DATE | NULL | - | Manager review deadline |
| `CALIBRATION_DUE` | DATE | NULL | - | Calibration deadline |
| `STATUS` | VARCHAR2(20) | NULL | `'DRAFT'` | `DRAFT`, `OPEN`, `IN_PROGRESS`, `CALIBRATION`, `CLOSED` |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`CYCLE_ID`), CHECK on `STATUS`

---

### 5.2 PERFORMANCE_REVIEWS

> Individual employee performance reviews within a cycle.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `REVIEW_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `CYCLE_ID` | NUMBER(10) | NOT NULL | - | FK to `REVIEW_CYCLES` |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` (reviewee) |
| `REVIEWER_EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` (reviewer/manager) |
| `REVIEW_TYPE` | VARCHAR2(20) | NULL | `'ANNUAL'` | Review type |
| `STATUS` | VARCHAR2(20) | NULL | `'NOT_STARTED'` | `NOT_STARTED`, `SELF_REVIEW`, `MANAGER_REVIEW`, `MEETING_SCHEDULED`, `COMPLETED`, `ACKNOWLEDGED` |
| `OVERALL_RATING` | NUMBER(2,1) | NULL | - | 1.0 to 5.0 scale |
| `RATING_LABEL` | VARCHAR2(50) | NULL | - | Derived label (Exceptional, Exceeds, Meets, Needs Improvement, Unsatisfactory) |
| `SELF_ASSESSMENT` | CLOB | NULL | - | Employee self-review text |
| `MANAGER_ASSESSMENT` | CLOB | NULL | - | Manager review text |
| `STRENGTHS` | CLOB | NULL | - | Identified strengths |
| `AREAS_FOR_IMPROVEMENT` | CLOB | NULL | - | Improvement areas |
| `DEVELOPMENT_PLAN` | CLOB | NULL | - | Development plan text |
| `EMPLOYEE_COMMENTS` | CLOB | NULL | - | Employee response |
| `EMPLOYEE_ACK_DATE` | DATE | NULL | - | Acknowledgment date |
| `CALIBRATED_RATING` | NUMBER(2,1) | NULL | - | Post-calibration rating |
| `CALIBRATION_NOTES` | VARCHAR2(4000) | NULL | - | Calibration notes |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`REVIEW_ID`), FKs to `REVIEW_CYCLES`, `EMPLOYEES` (x2), CHECK on `STATUS`, rating 1.0-5.0

---

### 5.3 PERFORMANCE_GOALS

> Individual goals linked to a performance review.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `GOAL_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `REVIEW_ID` | NUMBER(10) | NOT NULL | - | FK to `PERFORMANCE_REVIEWS` |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `GOAL_TITLE` | VARCHAR2(200) | NOT NULL | - | Goal title |
| `GOAL_DESCRIPTION` | CLOB | NULL | - | Detailed description |
| `GOAL_CATEGORY` | VARCHAR2(30) | NULL | - | `BUSINESS`, `DEVELOPMENT`, `LEADERSHIP`, `INNOVATION`, `COMPLIANCE` |
| `WEIGHT_PCT` | NUMBER(5,2) | NULL | `0` | Weight in overall score |
| `TARGET_DATE` | DATE | NULL | - | Due date |
| `STATUS` | VARCHAR2(20) | NULL | `'NOT_STARTED'` | `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED`, `DEFERRED`, `CANCELLED` |
| `PROGRESS_PCT` | NUMBER(5,2) | NULL | `0` | Completion percentage |
| `SELF_RATING` | NUMBER(2,1) | NULL | - | Employee self-rating |
| `MANAGER_RATING` | NUMBER(2,1) | NULL | - | Manager rating |
| `COMMENTS` | CLOB | NULL | - | Progress comments |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`GOAL_ID`), FKs to `PERFORMANCE_REVIEWS`, `EMPLOYEES`, CHECK on `STATUS`, `GOAL_CATEGORY`

---

## 6. System Domain

### 6.1 AUDIT_LOG

> Centralized audit trail for all DML operations system-wide.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `AUDIT_ID` | NUMBER(15) | NOT NULL | - | Primary key (`SEQ_AUDIT`, CACHE 100) |
| `TABLE_NAME` | VARCHAR2(60) | NOT NULL | - | Source table |
| `RECORD_ID` | NUMBER(15) | NOT NULL | - | Affected record PK |
| `ACTION_TYPE` | VARCHAR2(10) | NOT NULL | - | `INSERT`, `UPDATE`, `DELETE` |
| `OLD_VALUES` | CLOB | NULL | - | JSON-formatted old values |
| `NEW_VALUES` | CLOB | NULL | - | JSON-formatted new values |
| `CHANGED_BY` | VARCHAR2(30) | NOT NULL | - | User who made the change |
| `CHANGED_DATE` | DATE | NOT NULL | `SYSDATE` | When the change occurred |
| `IP_ADDRESS` | VARCHAR2(50) | NULL | - | Client IP |
| `SESSION_ID` | VARCHAR2(100) | NULL | - | Forms session ID |

**Constraints**: PK(`AUDIT_ID`), CHECK on `ACTION_TYPE`

---

### 6.2 SYSTEM_PARAMETERS

> Global application configuration (key-value store).

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `PARAM_ID` | NUMBER(5) | NOT NULL | - | Primary key |
| `PARAM_GROUP` | VARCHAR2(50) | NOT NULL | - | Category (e.g., `SECURITY`, `PAYROLL`, `INTEGRATION`) |
| `PARAM_CODE` | VARCHAR2(50) | NOT NULL | - | Parameter key |
| `PARAM_VALUE` | VARCHAR2(4000) | NOT NULL | - | Parameter value |
| `PARAM_DESCRIPTION` | VARCHAR2(200) | NULL | - | Description |
| `DATA_TYPE` | VARCHAR2(20) | NULL | `'VARCHAR2'` | Value data type |
| `EDITABLE_FLAG` | CHAR(1) | NULL | `'Y'` | Admin-editable |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |
| `MODIFIED_BY` | VARCHAR2(30) | NULL | - | Audit |
| `MODIFIED_DATE` | DATE | NULL | - | Audit |

**Constraints**: PK(`PARAM_ID`), UK(`PARAM_GROUP`, `PARAM_CODE`)
**Security Note**: FTP credentials stored in cleartext

---

### 6.3 NOTIFICATION_QUEUE

> Asynchronous notification delivery queue.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `NOTIFICATION_ID` | NUMBER(15) | NOT NULL | - | Primary key |
| `RECIPIENT_EMP_ID` | NUMBER(10) | NULL | - | FK to `EMPLOYEES` |
| `RECIPIENT_EMAIL` | VARCHAR2(100) | NULL | - | Override email |
| `NOTIFICATION_TYPE` | VARCHAR2(30) | NOT NULL | - | `EMAIL`, `IN_APP`, `SMS` |
| `SUBJECT` | VARCHAR2(200) | NOT NULL | - | Subject line |
| `BODY` | CLOB | NOT NULL | - | Message body |
| `STATUS` | VARCHAR2(20) | NULL | `'PENDING'` | `PENDING`, `SENT`, `FAILED`, `CANCELLED` |
| `PRIORITY` | NUMBER(2) | NULL | `5` | Delivery priority (1=highest) |
| `SENT_DATE` | DATE | NULL | - | When sent |
| `ERROR_MESSAGE` | VARCHAR2(4000) | NULL | - | Delivery error detail |
| `RETRY_COUNT` | NUMBER(3) | NULL | `0` | Number of retry attempts |
| `REFERENCE_TABLE` | VARCHAR2(60) | NULL | - | Source table reference |
| `REFERENCE_ID` | NUMBER(15) | NULL | - | Source record reference |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`NOTIFICATION_ID`), CHECK on `STATUS`, `NOTIFICATION_TYPE`

---

### 6.4 USER_SESSIONS

> Forms-specific session tracking for authentication.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `SESSION_ID` | NUMBER(15) | NOT NULL | - | Primary key |
| `EMP_ID` | NUMBER(10) | NOT NULL | - | FK to `EMPLOYEES` |
| `USERNAME` | VARCHAR2(30) | NOT NULL | - | Login username |
| `LOGIN_TIME` | DATE | NOT NULL | - | Session start |
| `LOGOUT_TIME` | DATE | NULL | - | Session end |
| `IP_ADDRESS` | VARCHAR2(50) | NULL | - | Client IP |
| `FORMS_MODULE` | VARCHAR2(100) | NULL | - | Active form module |
| `SESSION_STATUS` | VARCHAR2(20) | NULL | `'ACTIVE'` | Session state |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`SESSION_ID`), FK(`EMP_ID` -> `EMPLOYEES`)

---

### 6.5 LOOKUP_VALUES

> Generic lookup table for dropdown/LOV data.

| Column | Data Type | Nullable | Default | Description |
|---|---|---|---|---|
| `LOOKUP_ID` | NUMBER(10) | NOT NULL | - | Primary key |
| `LOOKUP_TYPE` | VARCHAR2(50) | NOT NULL | - | Category (e.g., `GENDER`, `MARITAL_STATUS`, `EMPLOYMENT_TYPE`) |
| `LOOKUP_CODE` | VARCHAR2(50) | NOT NULL | - | Value code |
| `LOOKUP_VALUE` | VARCHAR2(200) | NOT NULL | - | Display value |
| `DISPLAY_ORDER` | NUMBER(5) | NULL | `0` | Sort order |
| `PARENT_LOOKUP_ID` | NUMBER(10) | NULL | - | Hierarchical lookup support |
| `ACTIVE_FLAG` | CHAR(1) | NOT NULL | `'Y'` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | NOT NULL | - | Audit |
| `CREATED_DATE` | DATE | NOT NULL | `SYSDATE` | Audit |

**Constraints**: PK(`LOOKUP_ID`), UK(`LOOKUP_TYPE`, `LOOKUP_CODE`)

---

## 7. Entity Relationship Summary

```
LOCATIONS ─────────────┐
                       │ 1:N
JOB_GRADES ──┐         │
             │ 1:N     │
JOB_TITLES ──┘         │
    │                  │
    │ 1:N              │
    v                  v
DEPARTMENTS ──────> EMPLOYEES <──── (self-ref: MANAGER_EMP_ID)
    │                  │
    │                  ├──> EMPLOYEE_HISTORY
    │                  ├──> EMPLOYEE_DEPENDENTS
    │                  ├──> EMERGENCY_CONTACTS
    │                  ├──> SALARY_RECORDS ──> PAYROLL_DETAILS
    │                  ├──> EMPLOYEE_PAY_ELEMENTS ──> PAY_ELEMENTS
    │                  ├──> EMPLOYEE_TAX_INFO
    │                  ├──> EMPLOYEE_BANK_ACCOUNTS
    │                  ├──> LEAVE_BALANCES ──> LEAVE_TYPES
    │                  ├──> LEAVE_REQUESTS ──> LEAVE_TYPES
    │                  ├──> LEAVE_ACCRUAL_LOG
    │                  ├──> PERFORMANCE_REVIEWS ──> REVIEW_CYCLES
    │                  ├──> PERFORMANCE_GOALS
    │                  ├──> USER_SESSIONS
    │                  └──> NOTIFICATION_QUEUE
    │
    └──> AUDIT_LOG (via triggers)

PAY_PERIODS ──> PAYROLL_RUNS ──> PAYROLL_DETAILS
                                      │
                                      └──> PAY_ELEMENTS

HOLIDAYS (standalone)
SYSTEM_PARAMETERS (standalone)
LOOKUP_VALUES (standalone)
TAX_BRACKETS (standalone reference)
```

---

## 8. Common Patterns

| Pattern | Description | Applied To |
|---|---|---|
| **Surrogate Keys** | All PKs are sequences (`SEQ_*`), not natural keys | All tables except `LOCATIONS` |
| **Soft Deletes** | `ACTIVE_FLAG CHAR(1) DEFAULT 'Y'` | 20+ tables |
| **Audit Columns** | `CREATED_BY`, `CREATED_DATE`, `MODIFIED_BY`, `MODIFIED_DATE` | All tables |
| **Effective Dating** | `EFFECTIVE_DATE` / `END_DATE` pairs | `SALARY_RECORDS`, `EMPLOYEE_PAY_ELEMENTS` |
| **Status Workflows** | CHECK constraints with defined state machines | `PAYROLL_RUNS`, `LEAVE_REQUESTS`, `PERFORMANCE_REVIEWS`, `REVIEW_CYCLES` |
| **Virtual Columns** | Computed columns stored in metadata | `LEAVE_BALANCES.AVAILABLE` |
| **Encrypted Columns** | Sensitive data encrypted at rest | `EMPLOYEES.SSN_ENCRYPTED`, `EMPLOYEE_BANK_ACCOUNTS.ACCOUNT_NUMBER_ENC`, `EMPLOYEE_DEPENDENTS.SSN_ENCRYPTED` |
