# Data Dictionary

> **Schema**: HRMS  
> **Database**: Oracle 19c  
> **Tables**: 30 | **Views**: 6 | **Sequences**: 25  
> **Common Patterns**: Surrogate keys via sequences, soft deletes (`ACTIVE_FLAG`), audit columns on every table (`CREATED_BY`, `CREATED_DATE`, `MODIFIED_BY`, `MODIFIED_DATE`)

---

## Domain 1: Core HR (Employee & Organization)

**Source**: `schema/tables/01_core_tables.sql`  
**Business Context**: Central employee master data, organizational hierarchy, job classification, and physical locations.

### LOCATIONS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| LOCATION_CODE | VARCHAR2(10) | PK | Short code identifier (e.g., `HQ`, `CHI`, `SF`) |
| LOCATION_NAME | VARCHAR2(100) | NOT NULL | Full location name |
| ADDRESS_LINE1 | VARCHAR2(200) | | Street address |
| ADDRESS_LINE2 | VARCHAR2(200) | | Suite/floor |
| CITY | VARCHAR2(100) | | City |
| STATE_PROVINCE | VARCHAR2(100) | | State or province |
| POSTAL_CODE | VARCHAR2(20) | | Postal/ZIP code |
| COUNTRY_CODE | VARCHAR2(3) | DEFAULT 'US' | ISO country code |
| PHONE | VARCHAR2(30) | | Main office phone |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y', CHECK IN ('Y','N') | Soft delete flag |
| CREATED_BY | VARCHAR2(30) | | Audit: creator |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit: creation timestamp |
| MODIFIED_BY | VARCHAR2(30) | | Audit: last modifier |
| MODIFIED_DATE | DATE | | Audit: last modification |

**Seed Data**: 3 locations (Corporate HQ - New York, Chicago Regional, San Francisco Branch)

---

### JOB_GRADES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| GRADE_ID | NUMBER(10) | PK | Surrogate key |
| GRADE_NAME | VARCHAR2(50) | NOT NULL, UNIQUE | Display name (e.g., `Entry Level`, `Senior`, `C-Suite`) |
| GRADE_LEVEL | NUMBER(2) | NOT NULL, UNIQUE | Numeric level 1-10 for ordering |
| MIN_SALARY | NUMBER(12,2) | NOT NULL | Minimum salary for grade |
| MAX_SALARY | NUMBER(12,2) | NOT NULL | Maximum salary for grade |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete flag |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 10 grades from Entry Level ($35K-$55K) to C-Suite ($300K-$600K)

**Used By**: `PKG_VALIDATION.validate_salary_for_grade`, `PKG_SECURITY.has_permission` (grade-based RBAC), `HRMS_VALIDATION_LIB.validate_salary_range`, `VW_EMPLOYEE_COMPENSATION` (compa-ratio)

---

### JOB_TITLES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| JOB_ID | NUMBER(10) | PK | Surrogate key |
| JOB_CODE | VARCHAR2(20) | NOT NULL, UNIQUE | Short code (e.g., `CEO`, `SR-DEV`, `HR-SPEC`) |
| JOB_TITLE | VARCHAR2(100) | NOT NULL | Full job title |
| GRADE_ID | NUMBER(10) | FK -> JOB_GRADES | Compensation grade association |
| JOB_DESCRIPTION | CLOB | | Full job description |
| EEO_CATEGORY | VARCHAR2(10) | | EEO-1 reporting category |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete flag |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 26 job titles across 10 grades (CEO, CFO, CIO, VPs, Directors, Managers, Senior staff, Staff, Junior, Intern, Receptionist)

---

### DEPARTMENTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| DEPT_ID | NUMBER(10) | PK | Surrogate key |
| DEPT_CODE | VARCHAR2(10) | NOT NULL, UNIQUE | Short code (e.g., `HR`, `FIN`, `IT`, `ITDEV`) |
| DEPT_NAME | VARCHAR2(100) | NOT NULL | Full department name |
| COST_CENTER | VARCHAR2(20) | | GL cost center code (e.g., `CC-1100`) |
| PARENT_DEPT_ID | NUMBER(10) | FK -> DEPARTMENTS (self-ref) | Hierarchical parent; NULL for top-level |
| MANAGER_EMP_ID | NUMBER(10) | FK -> EMPLOYEES | Department head |
| LOCATION_CODE | VARCHAR2(10) | FK -> LOCATIONS | Primary location |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete flag |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 10 departments (Executive Office, HR, Finance, IT, IT-Development, IT-Operations, Sales, Marketing, Operations, Legal)

**Hierarchy**:
```
Executive Office (EXEC)
  +-- Human Resources (HR)
  +-- Finance & Accounting (FIN)
  +-- Information Technology (IT)
  |     +-- IT - Development (ITDEV)
  |     +-- IT - Operations (ITOPS)
  +-- Sales (SALES)
  +-- Marketing (MKT)
  +-- Operations (OPS)
  +-- Legal & Compliance (LEGAL)
```

---

### EMPLOYEES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| EMP_ID | NUMBER(10) | PK | Surrogate key via SEQ_EMPLOYEE |
| EMP_NUMBER | VARCHAR2(20) | NOT NULL, UNIQUE | Business key, format `EMP-NNNNNN` |
| FIRST_NAME | VARCHAR2(50) | NOT NULL | Stored uppercase (Forms CaseRestriction) |
| LAST_NAME | VARCHAR2(50) | NOT NULL | Stored uppercase |
| EMAIL | VARCHAR2(100) | UNIQUE | Login credential; stored lowercase |
| PHONE_WORK | VARCHAR2(30) | | Work phone |
| PHONE_MOBILE | VARCHAR2(30) | | Mobile phone |
| DATE_OF_BIRTH | DATE | | Date of birth |
| GENDER | VARCHAR2(1) | CHECK IN ('M','F','O') | M=Male, F=Female, O=Other |
| MARITAL_STATUS | VARCHAR2(10) | CHECK IN ('SINGLE','MARRIED','DIVORCED','WIDOWED') | Marital status |
| SSN_ENCRYPTED | RAW(256) | | SSN encrypted via DBMS_CRYPTO AES-256 |
| ADDRESS_LINE1 | VARCHAR2(200) | | Mailing address line 1 |
| ADDRESS_LINE2 | VARCHAR2(200) | | Mailing address line 2 |
| CITY | VARCHAR2(100) | | City |
| STATE_PROVINCE | VARCHAR2(100) | | State/province |
| POSTAL_CODE | VARCHAR2(20) | | Postal/ZIP code |
| COUNTRY_CODE | VARCHAR2(3) | DEFAULT 'US' | ISO country code |
| HIRE_DATE | DATE | NOT NULL | Original hire date |
| TERMINATION_DATE | DATE | | Termination date (NULL if active) |
| TERMINATION_REASON | VARCHAR2(50) | | VOLUNTARY / INVOLUNTARY / etc. |
| DEPT_ID | NUMBER(10) | FK -> DEPARTMENTS, NOT NULL | Current department |
| JOB_ID | NUMBER(10) | FK -> JOB_TITLES, NOT NULL | Current job title |
| MANAGER_EMP_ID | NUMBER(10) | FK -> EMPLOYEES (self-ref) | Reporting manager; NULL for CEO |
| LOCATION_CODE | VARCHAR2(10) | FK -> LOCATIONS | Work location |
| EMPLOYMENT_TYPE | VARCHAR2(20) | CHECK IN ('FULL_TIME','PART_TIME','CONTRACT','INTERN') | Employment category |
| EMPLOYMENT_STATUS | VARCHAR2(20) | CHECK IN ('ACTIVE','ON_LEAVE','SUSPENDED','TERMINATED') | Current status |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y', CHECK IN ('Y','N') | Soft delete flag |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 25 employees across all departments  
**Central Entity**: Referenced by virtually every other table in the schema

---

### EMPLOYEE_HISTORY

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| HISTORY_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee reference |
| CHANGE_TYPE | VARCHAR2(30) | NOT NULL | Type: `TRANSFER`, `PROMOTION`, `TERMINATION`, `REHIRE`, `STATUS_CHANGE` |
| CHANGE_DATE | DATE | DEFAULT SYSDATE | When the change occurred |
| OLD_VALUE | VARCHAR2(500) | | Previous value (JSON-like or descriptive) |
| NEW_VALUE | VARCHAR2(500) | | New value |
| CHANGED_BY | VARCHAR2(30) | | Who made the change |
| COMMENTS | VARCHAR2(1000) | | Free-text notes |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | DEFAULT SYSDATE | Audit |

**Written By**: `PKG_EMPLOYEE.log_history` (autonomous transaction)

---

### EMPLOYEE_DEPENDENTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| DEPENDENT_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Parent employee |
| FIRST_NAME | VARCHAR2(50) | NOT NULL | Dependent first name |
| LAST_NAME | VARCHAR2(50) | NOT NULL | Dependent last name |
| RELATIONSHIP | VARCHAR2(20) | NOT NULL | SPOUSE, CHILD, DOMESTIC_PARTNER, etc. |
| DATE_OF_BIRTH | DATE | | Dependent DOB |
| GENDER | VARCHAR2(1) | | M/F/O |
| SSN_ENCRYPTED | RAW(256) | | Encrypted SSN |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Used By**: `PKG_INTEGRATION.export_benefits_feed` (ADP format)

---

### EMERGENCY_CONTACTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| CONTACT_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Parent employee |
| CONTACT_NAME | VARCHAR2(100) | NOT NULL | Full name |
| RELATIONSHIP | VARCHAR2(30) | | Relationship to employee |
| PHONE_PRIMARY | VARCHAR2(30) | NOT NULL | Primary phone |
| PHONE_SECONDARY | VARCHAR2(30) | | Secondary phone |
| EMAIL | VARCHAR2(100) | | Email address |
| PRIORITY_ORDER | NUMBER(2) | DEFAULT 1 | Contact priority |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

## Domain 2: Payroll & Compensation

**Source**: `schema/tables/02_payroll_tables.sql`  
**Business Context**: Salary records, pay period management, payroll processing, tax calculations, and direct deposit.

### SALARY_RECORDS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| SALARY_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| BASE_SALARY | NUMBER(12,2) | NOT NULL | Annual base salary |
| EFFECTIVE_DATE | DATE | NOT NULL | Start date of this salary |
| END_DATE | DATE | | End date (NULL = current active salary) |
| CHANGE_REASON | VARCHAR2(50) | | HIRE, PROMOTION, ANNUAL_REVIEW, TRANSFER, ADJUSTMENT |
| CHANGE_PCT | NUMBER(5,2) | | Percentage change from previous salary |
| APPROVED_BY | VARCHAR2(30) | | Approver |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Active record indicator |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Pattern**: Only one record per employee has `ACTIVE_FLAG = 'Y'` at a time. `PKG_PAYROLL.create_salary_record` end-dates the previous active record before inserting.

---

### PAY_ELEMENTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| ELEMENT_ID | NUMBER(10) | PK | Surrogate key |
| ELEMENT_CODE | VARCHAR2(20) | NOT NULL, UNIQUE | Short code |
| ELEMENT_NAME | VARCHAR2(100) | NOT NULL | Display name |
| ELEMENT_TYPE | VARCHAR2(20) | CHECK IN ('EARNING','DEDUCTION','TAX','BENEFIT') | Category |
| CALCULATION_TYPE | VARCHAR2(20) | | FLAT, PERCENTAGE, FORMULA |
| DEFAULT_AMOUNT | NUMBER(12,2) | | Default flat amount |
| DEFAULT_PERCENTAGE | NUMBER(5,2) | | Default percentage |
| GL_ACCOUNT_CODE | VARCHAR2(30) | | GL account for journal posting |
| PRETAX_FLAG | VARCHAR2(1) | DEFAULT 'N' | Pre-tax deduction indicator |
| PRIORITY_ORDER | NUMBER(3) | | Processing order |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 8 pay elements (Base Salary, Overtime, Federal Tax, State Tax, Social Security, Medicare, 401k, Health Insurance)  
**Note**: Element IDs 100-103 are hard-coded in `PKG_PAYROLL` for tax elements

---

### EMPLOYEE_PAY_ELEMENTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| EPE_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| ELEMENT_ID | NUMBER(10) | FK -> PAY_ELEMENTS, NOT NULL | Pay element |
| AMOUNT | NUMBER(12,2) | | Override amount |
| PERCENTAGE | NUMBER(5,2) | | Override percentage |
| OVERRIDE_AMOUNT | NUMBER(12,2) | | One-time override |
| EFFECTIVE_DATE | DATE | NOT NULL | Start date |
| END_DATE | DATE | | End date (NULL = ongoing) |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

### PAY_PERIODS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| PERIOD_ID | NUMBER(10) | PK | Surrogate key |
| PERIOD_NAME | VARCHAR2(50) | NOT NULL | Display name (e.g., `January 2024`) |
| PERIOD_START_DATE | DATE | NOT NULL | Period start |
| PERIOD_END_DATE | DATE | NOT NULL | Period end |
| PAY_DATE | DATE | NOT NULL | Check/deposit date |
| PAY_FREQUENCY | VARCHAR2(20) | | MONTHLY, BIWEEKLY |
| STATUS | VARCHAR2(20) | DEFAULT 'OPEN', CHECK IN ('OPEN','PROCESSING','CLOSED') | Period status |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Generated By**: `PKG_PAYROLL.create_pay_periods` (batch generation for a year)

---

### PAYROLL_RUNS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| RUN_ID | NUMBER(10) | PK | Surrogate key |
| PERIOD_ID | NUMBER(10) | FK -> PAY_PERIODS, NOT NULL | Associated pay period |
| RUN_TYPE | VARCHAR2(20) | | REGULAR, SUPPLEMENTAL, BONUS, CORRECTION |
| RUN_DATE | DATE | DEFAULT SYSDATE | When the run was executed |
| STATUS | VARCHAR2(20) | DEFAULT 'PENDING' | PENDING -> CALCULATED -> APPROVED -> REVERSED |
| EMPLOYEE_COUNT | NUMBER(6) | | Number of employees processed |
| TOTAL_GROSS | NUMBER(15,2) | | Sum of all earnings |
| TOTAL_NET | NUMBER(15,2) | | Sum of all net pay |
| APPROVED_BY | VARCHAR2(30) | | Who approved the run |
| APPROVED_DATE | DATE | | When approved |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

### PAYROLL_DETAILS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| DETAIL_ID | NUMBER(10) | PK | Surrogate key |
| RUN_ID | NUMBER(10) | FK -> PAYROLL_RUNS, NOT NULL | Parent run |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| ELEMENT_ID | NUMBER(10) | FK -> PAY_ELEMENTS | Pay element |
| ELEMENT_TYPE | VARCHAR2(20) | | Denormalized from PAY_ELEMENTS |
| AMOUNT | NUMBER(12,2) | | Positive for earnings, negative for deductions |
| STATUS | VARCHAR2(20) | DEFAULT 'CALCULATED' | CALCULATED, ERROR, REVERSED |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Note**: `ELEMENT_TYPE` is denormalized here for query performance.

---

### TAX_BRACKETS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| BRACKET_ID | NUMBER(10) | PK | Surrogate key |
| TAX_YEAR | NUMBER(4) | NOT NULL | Tax year |
| TAX_TYPE | VARCHAR2(20) | | FEDERAL, STATE |
| FILING_STATUS | VARCHAR2(30) | | SINGLE, MARRIED_JOINT, MARRIED_SEPARATE, HEAD_OF_HOUSEHOLD |
| MIN_INCOME | NUMBER(12,2) | NOT NULL | Bracket lower bound |
| MAX_INCOME | NUMBER(12,2) | | Bracket upper bound (NULL = unlimited) |
| TAX_RATE | NUMBER(6,4) | NOT NULL | Marginal rate |
| BASE_TAX | NUMBER(12,2) | DEFAULT 0 | Cumulative tax at bracket start |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |

**Note**: Table exists but `PKG_PAYROLL.calculate_federal_tax` hard-codes 2024 brackets instead of reading from this table. See Technical Debt Report.

---

### EMPLOYEE_TAX_INFO

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| TAX_INFO_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| TAX_YEAR | NUMBER(4) | NOT NULL | Applicable tax year |
| FILING_STATUS | VARCHAR2(30) | | W-4 filing status |
| FEDERAL_ALLOWANCES | NUMBER(3) | DEFAULT 0 | Federal withholding allowances |
| STATE_CODE | VARCHAR2(2) | | State for state tax |
| STATE_ALLOWANCES | NUMBER(3) | DEFAULT 0 | State withholding allowances |
| ADDITIONAL_FEDERAL_WH | NUMBER(8,2) | DEFAULT 0 | Extra federal withholding per period |
| ADDITIONAL_STATE_WH | NUMBER(8,2) | DEFAULT 0 | Extra state withholding per period |
| EXEMPT_FLAG | VARCHAR2(1) | DEFAULT 'N' | Tax-exempt indicator |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Current year active record |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

### EMPLOYEE_BANK_ACCOUNTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| BANK_ACCOUNT_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| BANK_NAME | VARCHAR2(100) | NOT NULL | Financial institution |
| ACCOUNT_NUMBER_ENC | RAW(256) | | Encrypted account number (AES-256) |
| ROUTING_NUMBER | VARCHAR2(9) | NOT NULL | ABA routing number |
| ACCOUNT_TYPE | VARCHAR2(20) | | CHECKING, SAVINGS |
| DEPOSIT_TYPE | VARCHAR2(20) | | FULL, PERCENTAGE, FLAT |
| DEPOSIT_AMOUNT | NUMBER(12,2) | | Amount or percentage for split deposits |
| PRIORITY_ORDER | NUMBER(2) | DEFAULT 1 | Multi-account deposit ordering |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

## Domain 3: Leave & Absence

**Source**: `schema/tables/03_leave_tables.sql`  
**Business Context**: Leave type definitions, per-employee annual balances, leave request workflow, monthly accrual batch processing, and company holidays.

### LEAVE_TYPES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| LEAVE_TYPE_ID | NUMBER(10) | PK | Surrogate key |
| LEAVE_TYPE_CODE | VARCHAR2(10) | NOT NULL, UNIQUE | Short code (PTO, SICK, COMP, FMLA, JURY) |
| LEAVE_TYPE_NAME | VARCHAR2(50) | NOT NULL | Display name |
| ACCRUAL_FLAG | VARCHAR2(1) | DEFAULT 'N' | Whether this type accrues monthly |
| ACCRUAL_RATE | NUMBER(5,3) | | Days accrued per period |
| ACCRUAL_FREQUENCY | VARCHAR2(20) | | MONTHLY, ANNUAL |
| MAX_BALANCE | NUMBER(5,1) | | Maximum accrual cap |
| CARRYOVER_MAX | NUMBER(5,1) | | Max days carried to next year |
| CARRYOVER_EXPIRY | NUMBER(2) | | Months after year-end before carryover expires |
| REQUIRES_APPROVAL | VARCHAR2(1) | DEFAULT 'Y' | Manager approval required |
| MIN_TENURE_DAYS | NUMBER(5) | DEFAULT 0 | Minimum days employed to be eligible |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Seed Data**: 5 types:

| Code | Name | Accrual | Rate | Max Balance | Carryover | Min Tenure |
|------|------|---------|------|-------------|-----------|------------|
| PTO | Paid Time Off | Monthly | 1.25 days/mo | 20 days | 5 days (expires in 3 months) | 0 days |
| SICK | Sick Leave | Monthly | 0.833 days/mo | 10 days | 10 days (no expiry) | 0 days |
| COMP | Compensatory Time | No | - | - | 0 | 90 days |
| FMLA | Family Medical Leave | No | - | - | 0 | 365 days |
| JURY | Jury Duty | No | - | - | 0 | 0 days |

---

### LEAVE_BALANCES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| BALANCE_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| LEAVE_TYPE_ID | NUMBER(10) | FK -> LEAVE_TYPES, NOT NULL | Leave type |
| CALENDAR_YEAR | NUMBER(4) | NOT NULL | Year this balance applies to |
| OPENING_BALANCE | NUMBER(5,1) | DEFAULT 0 | Balance at year start |
| ACCRUED | NUMBER(5,1) | DEFAULT 0 | Total accrued this year |
| USED | NUMBER(5,1) | DEFAULT 0 | Total used this year |
| PENDING | NUMBER(5,1) | DEFAULT 0 | Currently pending approval |
| ADJUSTMENT | NUMBER(5,1) | DEFAULT 0 | Manual adjustments |
| CARRYOVER_FROM_PREV | NUMBER(5,1) | DEFAULT 0 | Days carried from previous year |
| CARRYOVER_EXPIRY_DT | DATE | | When carryover expires |
| **AVAILABLE** | **NUMBER (virtual)** | | **Computed: `OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT`** |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Unique Constraint**: (EMP_ID, LEAVE_TYPE_ID, CALENDAR_YEAR)

---

### LEAVE_REQUESTS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| REQUEST_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Requesting employee |
| LEAVE_TYPE_ID | NUMBER(10) | FK -> LEAVE_TYPES, NOT NULL | Leave type |
| START_DATE | DATE | NOT NULL | Leave start |
| END_DATE | DATE | NOT NULL | Leave end |
| TOTAL_DAYS | NUMBER(4,1) | NOT NULL | Business days (computed by `PKG_LEAVE.calculate_business_days`) |
| HALF_DAY_FLAG | VARCHAR2(1) | DEFAULT 'N' | Half-day indicator |
| HALF_DAY_PERIOD | VARCHAR2(2) | | AM or PM |
| STATUS | VARCHAR2(20) | NOT NULL | PENDING -> APPROVED/REJECTED -> TAKEN/CANCELLED |
| REASON | VARCHAR2(500) | | Employee-provided reason |
| APPROVER_EMP_ID | NUMBER(10) | FK -> EMPLOYEES | Manager who approves/rejects |
| APPROVAL_DATE | DATE | | When approved/rejected |
| APPROVAL_COMMENTS | VARCHAR2(500) | | Manager comments |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Status Workflow**: `PENDING` -> `APPROVED` -> `TAKEN` | `PENDING` -> `REJECTED` | `APPROVED` -> `CANCELLED`

---

### LEAVE_ACCRUAL_LOG

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| ACCRUAL_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| LEAVE_TYPE_ID | NUMBER(10) | FK -> LEAVE_TYPES, NOT NULL | Leave type |
| ACCRUAL_DATE | DATE | NOT NULL | Date of accrual |
| ACCRUAL_AMOUNT | NUMBER(5,3) | NOT NULL | Days accrued |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |

**Written By**: `PKG_LEAVE.run_monthly_accrual` (batch job, commits every 100 employees)

---

### HOLIDAYS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| HOLIDAY_ID | NUMBER(10) | PK | Surrogate key |
| HOLIDAY_DATE | DATE | NOT NULL | Holiday date |
| HOLIDAY_NAME | VARCHAR2(100) | NOT NULL | Display name |
| COUNTRY_CODE | VARCHAR2(3) | DEFAULT 'US' | Country |
| RECURRING_FLAG | VARCHAR2(1) | DEFAULT 'N' | Whether it recurs annually |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |

**Seed Data**: 10 US federal holidays (New Year, MLK Day, Presidents Day, Memorial Day, Juneteenth, Independence Day, Labor Day, Columbus Day, Veterans Day, Thanksgiving, Christmas)

**Bug**: `PKG_LEAVE.calculate_business_days` and `PKG_VALIDATION.is_business_day` only check exact date match - they do not handle observed holidays (e.g., when July 4 falls on a Saturday, the observed Friday is not excluded).

---

## Domain 4: Performance Management

**Source**: `schema/tables/04_performance_tables.sql` (first 3 tables)  
**Business Context**: Annual review cycles, employee performance reviews with self-assessment and manager evaluation, and goal tracking.

### REVIEW_CYCLES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| CYCLE_ID | NUMBER(10) | PK | Surrogate key |
| CYCLE_NAME | VARCHAR2(100) | NOT NULL | Display name (e.g., `2024 Annual Review`) |
| CYCLE_YEAR | NUMBER(4) | NOT NULL | Year |
| START_DATE | DATE | NOT NULL | Cycle start |
| END_DATE | DATE | NOT NULL | Cycle end |
| SELF_REVIEW_DUE | DATE | | Deadline for self-assessments |
| MANAGER_REVIEW_DUE | DATE | | Deadline for manager reviews |
| STATUS | VARCHAR2(20) | DEFAULT 'DRAFT' | DRAFT -> OPEN -> CLOSED |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

### PERFORMANCE_REVIEWS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| REVIEW_ID | NUMBER(10) | PK | Surrogate key |
| CYCLE_ID | NUMBER(10) | FK -> REVIEW_CYCLES, NOT NULL | Parent cycle |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee being reviewed |
| REVIEWER_EMP_ID | NUMBER(10) | FK -> EMPLOYEES | Reviewing manager |
| REVIEW_TYPE | VARCHAR2(20) | DEFAULT 'ANNUAL' | ANNUAL, MID_YEAR, PROBATION |
| STATUS | VARCHAR2(20) | DEFAULT 'NOT_STARTED' | NOT_STARTED -> SELF_REVIEW -> MANAGER_REVIEW -> COMPLETED -> ACKNOWLEDGED |
| OVERALL_RATING | NUMBER(3,1) | CHECK BETWEEN 1.0 AND 5.0 | Manager-assigned rating |
| RATING_LABEL | VARCHAR2(30) | | Computed: Exceptional / Exceeds / Meets / Needs Improvement / Unsatisfactory |
| SELF_ASSESSMENT | CLOB | | Employee self-assessment text |
| MANAGER_ASSESSMENT | CLOB | | Manager evaluation text |
| STRENGTHS | CLOB | | Key strengths |
| AREAS_FOR_IMPROVEMENT | CLOB | | Areas needing improvement |
| DEVELOPMENT_PLAN | CLOB | | Development plan text |
| EMPLOYEE_COMMENTS | CLOB | | Employee response to review |
| EMPLOYEE_ACK_DATE | DATE | | When employee acknowledged |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Rating Scale**:

| Rating Range | Label |
|-------------|-------|
| 4.5 - 5.0 | Exceptional |
| 3.5 - 4.4 | Exceeds Expectations |
| 2.5 - 3.4 | Meets Expectations |
| 1.5 - 2.4 | Needs Improvement |
| 1.0 - 1.4 | Unsatisfactory |

---

### PERFORMANCE_GOALS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| GOAL_ID | NUMBER(10) | PK | Surrogate key |
| REVIEW_ID | NUMBER(10) | FK -> PERFORMANCE_REVIEWS | Associated review |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Employee |
| GOAL_TITLE | VARCHAR2(200) | NOT NULL | Short goal title |
| GOAL_DESCRIPTION | CLOB | | Detailed description |
| GOAL_CATEGORY | VARCHAR2(20) | DEFAULT 'BUSINESS' | BUSINESS, DEVELOPMENT, LEADERSHIP |
| WEIGHT_PCT | NUMBER(3) | DEFAULT 0 | Weight as percentage of total |
| TARGET_DATE | DATE | | Goal due date |
| STATUS | VARCHAR2(20) | DEFAULT 'NOT_STARTED' | NOT_STARTED, IN_PROGRESS, COMPLETED, CANCELLED |
| PROGRESS_PCT | NUMBER(3) | DEFAULT 0 | 0-100 progress percentage |
| COMMENTS | CLOB | | Progress notes |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

---

## Domain 5: System & Cross-Cutting

**Source**: `schema/tables/04_performance_tables.sql` (remaining tables)  
**Business Context**: Audit trail, application configuration, notification queue, session management, and generic lookups.

### AUDIT_LOG

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| LOG_ID | NUMBER(10) | PK | Auto-generated (trigger or sequence) |
| TABLE_NAME | VARCHAR2(30) | NOT NULL | Table that was modified |
| RECORD_ID | NUMBER(10) | | Primary key of modified record |
| ACTION | VARCHAR2(10) | NOT NULL | INSERT, UPDATE, DELETE |
| OLD_VALUES | CLOB | | Previous column values (JSON-like) |
| NEW_VALUES | CLOB | | New column values (JSON-like) |
| PERFORMED_BY | VARCHAR2(30) | NOT NULL | User who made the change |
| PERFORMED_DATE | DATE | DEFAULT SYSDATE | Timestamp |
| IP_ADDRESS | VARCHAR2(45) | | Client IP from SYS_CONTEXT |
| SESSION_ID | NUMBER(10) | | Application session ID |

**Written By**: `PKG_AUDIT.log_action` (autonomous transaction), called by audit triggers and all domain packages

---

### SYSTEM_PARAMETERS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| PARAM_ID | NUMBER(10) | PK | Surrogate key |
| PARAM_CATEGORY | VARCHAR2(30) | NOT NULL | Category group |
| PARAM_NAME | VARCHAR2(50) | NOT NULL | Parameter name |
| PARAM_VALUE | VARCHAR2(500) | | Parameter value |
| DESCRIPTION | VARCHAR2(200) | | Human-readable description |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Unique Constraint**: (PARAM_CATEGORY, PARAM_NAME)  
**Security Risk**: FTP credentials for integration feeds stored here in cleartext

---

### NOTIFICATION_QUEUE

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| NOTIFICATION_ID | NUMBER(10) | PK | Surrogate key |
| RECIPIENT_EMP_ID | NUMBER(10) | FK -> EMPLOYEES | Target employee |
| NOTIFICATION_TYPE | VARCHAR2(20) | | EMAIL, SMS, IN_APP |
| SUBJECT | VARCHAR2(200) | | Message subject |
| BODY | CLOB | | Message body (may contain HTML) |
| STATUS | VARCHAR2(20) | DEFAULT 'PENDING' | PENDING -> SENT / FAILED -> CANCELLED |
| RETRY_COUNT | NUMBER(3) | DEFAULT 0 | Number of send attempts |
| SENT_DATE | DATE | | When successfully sent |
| ERROR_MESSAGE | VARCHAR2(500) | | Last error if FAILED |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |
| MODIFIED_BY | VARCHAR2(30) | | Audit |
| MODIFIED_DATE | DATE | | Audit |

**Processed By**: `PKG_NOTIFICATION.process_queue` (batch), uses UTL_SMTP

---

### USER_SESSIONS

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| SESSION_ID | NUMBER(10) | PK | Surrogate key |
| EMP_ID | NUMBER(10) | FK -> EMPLOYEES, NOT NULL | Logged-in employee |
| LOGIN_TIME | DATE | DEFAULT SYSDATE | Session start |
| LOGOUT_TIME | DATE | | Session end (NULL = still active) |
| IP_ADDRESS | VARCHAR2(45) | | Client IP |
| USER_AGENT | VARCHAR2(500) | | Client user agent |
| SESSION_STATUS | VARCHAR2(20) | DEFAULT 'ACTIVE' | ACTIVE, EXPIRED, LOGGED_OUT |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |

**Managed By**: `PKG_SECURITY.authenticate` (creates), `PKG_SECURITY.logout` (closes), `PKG_SECURITY.is_session_valid` (validates, 30-min timeout)

---

### LOOKUP_VALUES

| Column | Data Type | Constraints | Description |
|--------|-----------|-------------|-------------|
| LOOKUP_ID | NUMBER(10) | PK | Surrogate key |
| LOOKUP_TYPE | VARCHAR2(30) | NOT NULL | Category (e.g., `COUNTRY`, `STATUS`, `GENDER`) |
| LOOKUP_CODE | VARCHAR2(30) | NOT NULL | Code value |
| LOOKUP_VALUE | VARCHAR2(100) | NOT NULL | Display value |
| DISPLAY_ORDER | NUMBER(3) | | Sort order |
| ACTIVE_FLAG | VARCHAR2(1) | DEFAULT 'Y' | Soft delete |
| CREATED_BY | VARCHAR2(30) | | Audit |
| CREATED_DATE | DATE | | Audit |

**Unique Constraint**: (LOOKUP_TYPE, LOOKUP_CODE)

---

## Views

**Source**: `schema/views/hrms_views.sql`

### VW_ACTIVE_EMPLOYEES
```sql
-- Denormalized roster of active employees with org data
SELECT e.*, d.DEPT_NAME, d.COST_CENTER, j.JOB_TITLE, g.GRADE_NAME, l.LOCATION_NAME
FROM EMPLOYEES e
JOIN DEPARTMENTS d ...
JOIN JOB_TITLES j ...
JOIN JOB_GRADES g ...
LEFT JOIN LOCATIONS l ...
WHERE e.EMPLOYMENT_STATUS = 'ACTIVE' AND e.ACTIVE_FLAG = 'Y'
```

### VW_ORG_HIERARCHY
```sql
-- Recursive org chart via CONNECT BY
SELECT LEVEL, EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME, MANAGER_EMP_ID, JOB_TITLE
FROM EMPLOYEES e JOIN JOB_TITLES j ...
CONNECT BY PRIOR e.EMP_ID = e.MANAGER_EMP_ID
START WITH e.MANAGER_EMP_ID IS NULL
```

### VW_EMPLOYEE_COMPENSATION
```sql
-- Current salary with compa-ratio (salary / grade midpoint)
SELECT e.*, sr.BASE_SALARY,
       ROUND(sr.BASE_SALARY / ((g.MIN_SALARY + g.MAX_SALARY) / 2) * 100, 1) AS COMPA_RATIO
FROM EMPLOYEES e
JOIN SALARY_RECORDS sr ON ... AND sr.ACTIVE_FLAG = 'Y'
JOIN JOB_GRADES g ...
```

### VW_LEAVE_SUMMARY
```sql
-- Current year leave balances per employee/type
SELECT e.EMP_NUMBER, e.FIRST_NAME, e.LAST_NAME, lt.LEAVE_TYPE_NAME,
       lb.OPENING_BALANCE, lb.ACCRUED, lb.USED, lb.PENDING, lb.AVAILABLE
FROM LEAVE_BALANCES lb ...
WHERE lb.CALENDAR_YEAR = EXTRACT(YEAR FROM SYSDATE)
```

### VW_PAYROLL_LATEST
```sql
-- Latest payroll run with gross/deduction/net totals
SELECT pr.RUN_ID, pp.PERIOD_NAME,
       SUM(CASE WHEN pd.ELEMENT_TYPE='EARNING' THEN pd.AMOUNT END) AS GROSS, ...
FROM PAYROLL_DETAILS pd ...
WHERE pr.STATUS != 'REVERSED'
```

### VW_PENDING_APPROVALS
```sql
-- Pending leave requests for approver dashboards
SELECT lr.REQUEST_ID, e.FIRST_NAME || ' ' || e.LAST_NAME, lt.LEAVE_TYPE_NAME, ...
FROM LEAVE_REQUESTS lr ...
WHERE lr.STATUS = 'PENDING'
```

---

## Entity-Relationship Summary

```
LOCATIONS ----< DEPARTMENTS ----< EMPLOYEES >---- JOB_TITLES >---- JOB_GRADES
                     |               |    |
                     |               |    +------< EMPLOYEE_HISTORY
                     |               |    +------< EMPLOYEE_DEPENDENTS
                     |               |    +------< EMERGENCY_CONTACTS
                     |               |    +------< SALARY_RECORDS
                     |               |    +------< EMPLOYEE_PAY_ELEMENTS >---- PAY_ELEMENTS
                     |               |    +------< EMPLOYEE_TAX_INFO
                     |               |    +------< EMPLOYEE_BANK_ACCOUNTS
                     |               |    +------< LEAVE_BALANCES >---- LEAVE_TYPES
                     |               |    +------< LEAVE_REQUESTS
                     |               |    +------< LEAVE_ACCRUAL_LOG
                     |               |    +------< PERFORMANCE_REVIEWS >---- REVIEW_CYCLES
                     |               |    +------< PERFORMANCE_GOALS
                     |               |    +------< NOTIFICATION_QUEUE
                     |               |    +------< USER_SESSIONS
                     |               |
                     |               +---- MANAGER_EMP_ID (self-ref FK)
                     +---- PARENT_DEPT_ID (self-ref FK)

PAY_PERIODS ----< PAYROLL_RUNS ----< PAYROLL_DETAILS

AUDIT_LOG (cross-cutting, no FKs)
SYSTEM_PARAMETERS (standalone config)
LOOKUP_VALUES (standalone reference)
HOLIDAYS (standalone reference)
```
