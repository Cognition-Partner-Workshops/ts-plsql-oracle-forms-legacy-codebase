# Data Dictionary

> **HRMS Schema** — Oracle Database 19c
> Business entities extracted from DDL schemas, grouped by functional domain.

---

## Table of Contents

1. [Domain Overview](#1-domain-overview)
2. [Core HR Domain](#2-core-hr-domain)
3. [Payroll Domain](#3-payroll-domain)
4. [Leave Management Domain](#4-leave-management-domain)
5. [Performance Management Domain](#5-performance-management-domain)
6. [System & Audit Domain](#6-system--audit-domain)
7. [Reporting Views](#7-reporting-views)
8. [Cross-Domain Relationships](#8-cross-domain-relationships)

---

## 1. Domain Overview

| Domain | Tables | Views | Sequences | Description |
|--------|-------:|------:|----------:|-------------|
| Core HR | 8 | 2 | 6 | Employee master data, org structure, job catalog |
| Payroll | 9 | 2 | 7 | Salary, pay periods, tax, deductions, bank accounts |
| Leave Management | 5 | 1 | 5 | Leave types, balances, requests, accrual, holidays |
| Performance Management | 3 | 0 | 3 | Review cycles, reviews, goals |
| System & Audit | 5 | 1 | 4 | Audit log, sessions, notifications, config, lookups |
| **Total** | **30** | **6** | **25** | |

**Common Patterns Across All Tables:**

| Pattern | Description |
|---------|-------------|
| Surrogate Keys | All primary keys are system-generated via Oracle sequences |
| Audit Columns | `CREATED_BY`, `CREATED_DATE`, `MODIFIED_BY`, `MODIFIED_DATE` on every table |
| Soft Delete | `ACTIVE_FLAG CHAR(1) DEFAULT 'Y'` — records deactivated rather than deleted |
| Naming | Table names are plural nouns; columns use `UPPER_SNAKE_CASE` |

---

## 2. Core HR Domain

### 2.1 EMPLOYEES

> **Business Purpose:** Central employee master record storing personal, employment, and contact information. One row per employee (current and historical).

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `EMP_ID` | NUMBER(10) | No | `SEQ_EMPLOYEE.NEXTVAL` | **PK** | Surrogate key |
| `EMP_NUMBER` | VARCHAR2(20) | No | — | UNIQUE | Human-readable employee number (format: `EMP-NNNNNN`) |
| `FIRST_NAME` | VARCHAR2(50) | No | — | — | First name (stored uppercase) |
| `LAST_NAME` | VARCHAR2(50) | No | — | — | Last name (stored uppercase) |
| `MIDDLE_NAME` | VARCHAR2(50) | Yes | — | — | Middle name |
| `DATE_OF_BIRTH` | DATE | Yes | — | — | Date of birth |
| `GENDER` | CHAR(1) | Yes | — | `CHECK IN ('M','F','O')` | Gender code |
| `MARITAL_STATUS` | VARCHAR2(10) | Yes | — | `CHECK IN ('SINGLE','MARRIED','DIVORCED','WIDOWED')` | Marital status |
| `SSN_ENCRYPTED` | RAW(256) | Yes | — | — | Social Security Number (AES-256 encrypted via `PKG_SECURITY`) |
| `EMAIL` | VARCHAR2(100) | Yes | — | UNIQUE | Corporate email (used as login username) |
| `PHONE_WORK` | VARCHAR2(30) | Yes | — | — | Work phone number |
| `PHONE_MOBILE` | VARCHAR2(30) | Yes | — | — | Mobile phone number |
| `ADDRESS_LINE1` | VARCHAR2(200) | Yes | — | — | Street address line 1 |
| `ADDRESS_LINE2` | VARCHAR2(200) | Yes | — | — | Street address line 2 |
| `CITY` | VARCHAR2(100) | Yes | — | — | City |
| `STATE_PROVINCE` | VARCHAR2(100) | Yes | — | — | State or province |
| `POSTAL_CODE` | VARCHAR2(20) | Yes | — | — | ZIP/postal code |
| `COUNTRY_CODE` | VARCHAR2(3) | Yes | `'US'` | — | ISO country code |
| `HIRE_DATE` | DATE | No | — | — | Original hire date |
| `TERMINATION_DATE` | DATE | Yes | — | — | Date of termination (NULL if active) |
| `TERMINATION_REASON` | VARCHAR2(50) | Yes | — | — | Reason code (VOLUNTARY, INVOLUNTARY, etc.) |
| `DEPT_ID` | NUMBER(10) | No | — | **FK → DEPARTMENTS** | Current department |
| `JOB_ID` | NUMBER(10) | No | — | **FK → JOB_TITLES** | Current job title |
| `MANAGER_EMP_ID` | NUMBER(10) | Yes | — | **FK → EMPLOYEES (self)** | Direct manager (NULL for CEO) |
| `LOCATION_CODE` | VARCHAR2(10) | Yes | — | **FK → LOCATIONS** | Work location |
| `EMPLOYMENT_TYPE` | VARCHAR2(20) | No | `'FULL_TIME'` | `CHECK IN ('FULL_TIME','PART_TIME','CONTRACT','INTERN')` | Employment type |
| `EMPLOYMENT_STATUS` | VARCHAR2(20) | No | `'ACTIVE'` | `CHECK IN ('ACTIVE','ON_LEAVE','SUSPENDED','TERMINATED')` | Current status |
| `PASSWORD_HASH` | VARCHAR2(64) | Yes | — | — | MD5 password hash |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | `CHECK IN ('Y','N')` | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | Creator username |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | Creation timestamp |
| `MODIFIED_BY` | VARCHAR2(30) | Yes | — | — | Last modifier |
| `MODIFIED_DATE` | DATE | Yes | — | — | Last modification timestamp |

**Indexes:** PK on `EMP_ID`, UNIQUE on `EMP_NUMBER`, UNIQUE on `EMAIL`
**Triggers:** `TRG_EMP_BEFORE_INSERT`, `TRG_EMP_BEFORE_UPDATE`, `TRG_EMP_AFTER_INSERT`, `TRG_EMP_AFTER_UPDATE`, `TRG_EMP_INSTEAD_OF_DELETE` (on view)

---

### 2.2 DEPARTMENTS

> **Business Purpose:** Organizational units with hierarchical parent-child structure supporting the company org chart. Each department has a cost center for GL accounting.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `DEPT_ID` | NUMBER(10) | No | `SEQ_DEPARTMENT.NEXTVAL` | **PK** | Surrogate key |
| `DEPT_CODE` | VARCHAR2(10) | No | — | UNIQUE | Short department code |
| `DEPT_NAME` | VARCHAR2(100) | No | — | — | Full department name |
| `COST_CENTER` | VARCHAR2(20) | Yes | — | — | Cost center code for GL posting |
| `PARENT_DEPT_ID` | NUMBER(10) | Yes | — | **FK → DEPARTMENTS (self)** | Parent department (NULL for root) |
| `MANAGER_EMP_ID` | NUMBER(10) | Yes | — | **FK → EMPLOYEES** | Department head |
| `LOCATION_CODE` | VARCHAR2(10) | Yes | — | **FK → LOCATIONS** | Primary location |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Seed Data:** 10 departments (Executive, HR, Finance, IT, IT-Dev, IT-Ops, Sales, Marketing, Operations, Legal)

---

### 2.3 LOCATIONS

> **Business Purpose:** Physical office locations where employees work. Used for reporting, tax jurisdiction, and contact information.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `LOCATION_CODE` | VARCHAR2(10) | No | — | **PK** | Natural key (e.g., 'HQ', 'CHI', 'SF') |
| `LOCATION_NAME` | VARCHAR2(100) | No | — | — | Full location name |
| `ADDRESS_LINE1` | VARCHAR2(200) | Yes | — | — | Street address |
| `CITY` | VARCHAR2(100) | Yes | — | — | City |
| `STATE_PROVINCE` | VARCHAR2(100) | Yes | — | — | State/province |
| `POSTAL_CODE` | VARCHAR2(20) | Yes | — | — | ZIP/postal code |
| `COUNTRY_CODE` | VARCHAR2(3) | Yes | `'US'` | — | ISO country code |
| `PHONE` | VARCHAR2(30) | Yes | — | — | Office phone |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | Soft delete flag |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Seed Data:** 3 locations (New York HQ, Chicago Regional, San Francisco Branch)

---

### 2.4 JOB_GRADES

> **Business Purpose:** Salary grade bands defining minimum and maximum compensation for each level. Used for salary validation and compa-ratio calculations.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `GRADE_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `GRADE_NAME` | VARCHAR2(50) | No | — | — | Grade display name |
| `GRADE_LEVEL` | NUMBER(3) | No | — | — | Numeric level (1=Entry, 10=C-Suite) |
| `MIN_SALARY` | NUMBER(12,2) | No | — | — | Minimum salary for grade |
| `MAX_SALARY` | NUMBER(12,2) | No | — | — | Maximum salary for grade |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Seed Data:** 10 grades (Entry Level $35K-$55K through C-Suite $300K-$600K)

---

### 2.5 JOB_TITLES

> **Business Purpose:** Job catalog linking positions to salary grades and EEO compliance categories.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `JOB_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `JOB_CODE` | VARCHAR2(20) | No | — | UNIQUE | Short job code |
| `JOB_TITLE` | VARCHAR2(100) | No | — | — | Full title |
| `GRADE_ID` | NUMBER(10) | No | — | **FK → JOB_GRADES** | Linked salary grade |
| `EEO_CATEGORY` | VARCHAR2(10) | Yes | — | — | EEO compliance category |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Seed Data:** 26 job titles across all departments

---

### 2.6 EMPLOYEE_HISTORY

> **Business Purpose:** Change tracking for employee field changes (department, job, status, salary). Populated by `TRG_EMP_BEFORE_UPDATE` trigger.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `HISTORY_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee reference |
| `CHANGE_DATE` | DATE | No | `SYSDATE` | — | When the change occurred |
| `CHANGE_TYPE` | VARCHAR2(30) | No | — | — | Type of change (STATUS, DEPARTMENT, JOB, SALARY) |
| `OLD_VALUE` | VARCHAR2(200) | Yes | — | — | Previous value |
| `NEW_VALUE` | VARCHAR2(200) | Yes | — | — | New value |
| `CHANGED_BY` | VARCHAR2(30) | No | — | — | Who made the change |
| `COMMENTS` | VARCHAR2(500) | Yes | — | — | Optional notes |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 2.7 EMPLOYEE_DEPENDENTS

> **Business Purpose:** Dependent information for benefits enrollment and emergency contact purposes.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `DEPENDENT_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Parent employee |
| `FIRST_NAME` | VARCHAR2(50) | No | — | — | Dependent first name |
| `LAST_NAME` | VARCHAR2(50) | No | — | — | Dependent last name |
| `RELATIONSHIP` | VARCHAR2(20) | No | — | — | Relationship (SPOUSE, CHILD, DOMESTIC_PARTNER, etc.) |
| `DATE_OF_BIRTH` | DATE | Yes | — | — | Date of birth |
| `GENDER` | CHAR(1) | Yes | — | — | |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 2.8 EMERGENCY_CONTACTS

> **Business Purpose:** Emergency contact information for each employee.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `CONTACT_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee reference |
| `CONTACT_NAME` | VARCHAR2(100) | No | — | — | Full name |
| `RELATIONSHIP` | VARCHAR2(20) | No | — | — | Relationship to employee |
| `PHONE_PRIMARY` | VARCHAR2(30) | No | — | — | Primary phone |
| `PHONE_SECONDARY` | VARCHAR2(30) | Yes | — | — | Secondary phone |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

## 3. Payroll Domain

### 3.1 SALARY_RECORDS

> **Business Purpose:** Historical salary records with effective dating. Only one record per employee has `ACTIVE_FLAG = 'Y'` at any time. Change percentage is tracked for reporting.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `SALARY_ID` | NUMBER(10) | No | `SEQ_SALARY.NEXTVAL` | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee reference |
| `EFFECTIVE_DATE` | DATE | No | — | — | Start date of this salary |
| `END_DATE` | DATE | Yes | — | — | End date (NULL = current) |
| `BASE_SALARY` | NUMBER(12,2) | No | — | — | Annual base salary |
| `CURRENCY_CODE` | VARCHAR2(3) | No | `'USD'` | — | Currency |
| `PAY_FREQUENCY` | VARCHAR2(20) | No | `'MONTHLY'` | — | MONTHLY, BIWEEKLY |
| `CHANGE_REASON` | VARCHAR2(50) | Yes | — | — | HIRE, PROMOTION, ANNUAL_REVIEW, TRANSFER, etc. |
| `CHANGE_PCT` | NUMBER(5,2) | Yes | — | — | Percentage change from previous salary |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | Only one active per employee |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Triggers:** `TRG_SALARY_BEFORE_INSERT` — auto-generates ID, calculates `CHANGE_PCT`

---

### 3.2 PAY_ELEMENTS

> **Business Purpose:** Master list of pay element types (earnings, deductions, benefits, taxes) with GL account codes for financial integration.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `ELEMENT_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `ELEMENT_CODE` | VARCHAR2(20) | No | — | UNIQUE | Short code |
| `ELEMENT_NAME` | VARCHAR2(100) | No | — | — | Display name |
| `ELEMENT_TYPE` | VARCHAR2(20) | No | — | `CHECK IN ('EARNING','DEDUCTION','BENEFIT','TAX')` | Category |
| `GL_ACCOUNT_CODE` | VARCHAR2(30) | Yes | — | — | GL account for financial integration |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 3.3 EMPLOYEE_PAY_ELEMENTS

> **Business Purpose:** Links employees to recurring pay elements (e.g., 401k deductions, health insurance) with amounts/percentages and effective dates.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `EMP_ELEMENT_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee |
| `ELEMENT_ID` | NUMBER(10) | No | — | **FK → PAY_ELEMENTS** | Pay element |
| `AMOUNT` | NUMBER(12,2) | Yes | — | — | Fixed amount (if applicable) |
| `PERCENTAGE` | NUMBER(5,2) | Yes | — | — | Percentage of gross (if applicable) |
| `EFFECTIVE_DATE` | DATE | No | — | — | Start date |
| `END_DATE` | DATE | Yes | — | — | End date (NULL = current) |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 3.4 PAY_PERIODS

> **Business Purpose:** Pay period definitions for each calendar year. Generated by `PKG_PAYROLL.create_pay_periods` for MONTHLY or BIWEEKLY frequencies.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `PERIOD_ID` | NUMBER(10) | No | `SEQ_PAY_PERIOD.NEXTVAL` | **PK** | Surrogate key |
| `PERIOD_NAME` | VARCHAR2(50) | No | — | — | Display name (e.g., "January 2024") |
| `PERIOD_START_DATE` | DATE | No | — | — | Period start |
| `PERIOD_END_DATE` | DATE | No | — | — | Period end |
| `PAY_DATE` | DATE | No | — | — | Date employees are paid |
| `PAY_FREQUENCY` | VARCHAR2(20) | No | — | — | MONTHLY or BIWEEKLY |
| `STATUS` | VARCHAR2(20) | No | `'OPEN'` | `CHECK IN ('OPEN','CLOSED','PROCESSING')` | Period status |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |
| `FISCAL_YEAR` | NUMBER(4) | Yes | — | — | Fiscal year |

---

### 3.5 PAYROLL_RUNS

> **Business Purpose:** Records of payroll execution within a pay period. Tracks status from PENDING through CALCULATED, APPROVED, to PAID.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `RUN_ID` | NUMBER(10) | No | `SEQ_PAYROLL_RUN.NEXTVAL` | **PK** | Surrogate key |
| `PERIOD_ID` | NUMBER(10) | No | — | **FK → PAY_PERIODS** | Pay period |
| `RUN_TYPE` | VARCHAR2(20) | No | `'REGULAR'` | — | REGULAR, SUPPLEMENTAL, CORRECTION |
| `RUN_DATE` | DATE | No | `SYSDATE` | — | Execution timestamp |
| `STATUS` | VARCHAR2(20) | No | `'PENDING'` | `CHECK IN ('PENDING','CALCULATED','APPROVED','PAID','REVERSED','ERROR')` | Run status |
| `EMPLOYEE_COUNT` | NUMBER(6) | Yes | — | — | Number of employees processed |
| `TOTAL_GROSS` | NUMBER(15,2) | Yes | — | — | Total gross pay |
| `TOTAL_NET` | NUMBER(15,2) | Yes | — | — | Total net pay |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 3.6 PAYROLL_DETAILS

> **Business Purpose:** Individual payroll line items — one row per employee per pay element per payroll run. Amounts are positive for earnings, negative for deductions/taxes.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `DETAIL_ID` | NUMBER(10) | No | `SEQ_PAYROLL_DETAIL.NEXTVAL` | **PK** | Surrogate key |
| `RUN_ID` | NUMBER(10) | No | — | **FK → PAYROLL_RUNS** | Payroll run |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee |
| `ELEMENT_ID` | NUMBER(10) | No | — | **FK → PAY_ELEMENTS** | Pay element |
| `ELEMENT_TYPE` | VARCHAR2(20) | No | — | — | Denormalized from PAY_ELEMENTS |
| `AMOUNT` | NUMBER(12,2) | No | — | — | Amount (positive=earning, negative=deduction) |
| `STATUS` | VARCHAR2(20) | No | `'CALCULATED'` | — | CALCULATED, APPROVED, PAID, ERROR |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |
| `HOURS` | NUMBER(5,2) | Yes | — | — | Hours (for hourly elements) |

---

### 3.7 TAX_BRACKETS

> **Business Purpose:** Federal and state tax bracket definitions. Currently contains hard-coded 2024 tax rates.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `BRACKET_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `TAX_TYPE` | VARCHAR2(20) | No | — | — | FEDERAL, STATE |
| `FILING_STATUS` | VARCHAR2(20) | No | — | — | SINGLE, MARRIED_JOINT, MARRIED_SEPARATE, HEAD_OF_HOUSEHOLD |
| `MIN_INCOME` | NUMBER(12,2) | No | — | — | Lower bound |
| `MAX_INCOME` | NUMBER(12,2) | Yes | — | — | Upper bound (NULL = no cap) |
| `TAX_RATE` | NUMBER(5,4) | No | — | — | Marginal rate |
| `TAX_YEAR` | NUMBER(4) | No | — | — | Applicable year |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 3.8 EMPLOYEE_TAX_INFO

> **Business Purpose:** Employee tax withholding elections (W-4 information) — filing status, exemptions, additional withholding, and state of residence.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `TAX_INFO_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee |
| `FEDERAL_FILING_STATUS` | VARCHAR2(20) | No | — | — | Federal filing status |
| `FEDERAL_EXEMPTIONS` | NUMBER(3) | No | `0` | — | Number of exemptions |
| `ADDITIONAL_FEDERAL_WH` | NUMBER(12,2) | No | `0` | — | Additional federal withholding |
| `STATE_CODE` | VARCHAR2(2) | Yes | — | — | State of residence |
| `STATE_FILING_STATUS` | VARCHAR2(20) | Yes | — | — | State filing status |
| `ADDITIONAL_STATE_WH` | NUMBER(12,2) | No | `0` | — | Additional state withholding |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 3.9 EMPLOYEE_BANK_ACCOUNTS

> **Business Purpose:** Direct deposit banking information for payroll disbursement.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `ACCOUNT_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee |
| `BANK_NAME` | VARCHAR2(100) | No | — | — | Bank name |
| `ROUTING_NUMBER` | VARCHAR2(9) | No | — | — | ABA routing number |
| `ACCOUNT_NUMBER` | VARCHAR2(20) | No | — | — | Bank account number |
| `ACCOUNT_TYPE` | VARCHAR2(10) | No | — | `CHECK IN ('CHECKING','SAVINGS')` | Account type |
| `DEPOSIT_TYPE` | VARCHAR2(10) | No | — | — | FULL, PARTIAL, FLAT_AMOUNT |
| `DEPOSIT_AMOUNT` | NUMBER(12,2) | Yes | — | — | Amount for partial/flat deposits |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |

---

## 4. Leave Management Domain

### 4.1 LEAVE_TYPES

> **Business Purpose:** Master list of leave type definitions with accrual rules, carryover policies, and approval requirements.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `LEAVE_TYPE_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `LEAVE_TYPE_CODE` | VARCHAR2(10) | No | — | UNIQUE | Short code (PTO, SICK, COMP, FMLA, JURY) |
| `LEAVE_TYPE_NAME` | VARCHAR2(50) | No | — | — | Display name |
| `ACCRUAL_FLAG` | CHAR(1) | No | `'N'` | — | Whether leave accrues over time |
| `ACCRUAL_RATE` | NUMBER(5,3) | Yes | — | — | Days accrued per frequency period |
| `ACCRUAL_FREQUENCY` | VARCHAR2(20) | Yes | — | — | MONTHLY, QUARTERLY, ANNUAL |
| `MAX_BALANCE` | NUMBER(5,1) | Yes | — | — | Maximum balance cap (NULL = unlimited) |
| `CARRYOVER_MAX` | NUMBER(5,1) | Yes | — | — | Max days that can carry to next year |
| `CARRYOVER_EXPIRY` | NUMBER(3) | Yes | — | — | Months after year-start when carryover expires |
| `REQUIRES_APPROVAL` | CHAR(1) | No | `'Y'` | — | Whether manager approval is needed |
| `MIN_TENURE_DAYS` | NUMBER(5) | No | `0` | — | Minimum employment days to be eligible |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Seed Data:** PTO (1.25 days/month, max 20, carryover 5 with 3-month expiry), Sick (0.833 days/month, max 10, full carryover), Compensatory, FMLA, Jury Duty

---

### 4.2 LEAVE_BALANCES

> **Business Purpose:** Per-employee per-leave-type annual balance tracking. Contains a virtual column `AVAILABLE` that computes the available balance.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `EMP_ID` | NUMBER(10) | No | — | **PK (composite)**, FK → EMPLOYEES | Employee |
| `LEAVE_TYPE_ID` | NUMBER(10) | No | — | **PK (composite)**, FK → LEAVE_TYPES | Leave type |
| `CALENDAR_YEAR` | NUMBER(4) | No | — | **PK (composite)** | Balance year |
| `OPENING_BALANCE` | NUMBER(5,1) | No | `0` | — | Balance at start of year |
| `ACCRUED` | NUMBER(5,1) | No | `0` | — | Total accrued during year |
| `USED` | NUMBER(5,1) | No | `0` | — | Days taken |
| `PENDING` | NUMBER(5,1) | No | `0` | — | Days in pending requests |
| `ADJUSTMENT` | NUMBER(5,1) | No | `0` | — | Manual adjustments |
| `CARRYOVER_FROM_PREV` | NUMBER(5,1) | No | `0` | — | Carried over from previous year |
| `CARRYOVER_EXPIRY_DT` | DATE | Yes | — | — | When carryover expires |
| `AVAILABLE` | NUMBER | — | — | **Virtual column** | `OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT - PENDING` |
| `MODIFIED_BY` | VARCHAR2(30) | Yes | — | — | |
| `MODIFIED_DATE` | DATE | Yes | — | — | |

---

### 4.3 LEAVE_REQUESTS

> **Business Purpose:** Individual leave request records with full approval workflow tracking.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `REQUEST_ID` | NUMBER(10) | No | `SEQ_LEAVE_REQUEST.NEXTVAL` | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Requesting employee |
| `LEAVE_TYPE_ID` | NUMBER(10) | No | — | **FK → LEAVE_TYPES** | Leave type |
| `START_DATE` | DATE | No | — | — | Leave start date |
| `END_DATE` | DATE | No | — | — | Leave end date |
| `TOTAL_DAYS` | NUMBER(5,1) | No | — | — | Total business days |
| `HALF_DAY_FLAG` | CHAR(1) | No | `'N'` | — | Half-day request |
| `STATUS` | VARCHAR2(20) | No | `'PENDING'` | `CHECK IN ('PENDING','APPROVED','REJECTED','CANCELLED','TAKEN')` | Workflow status |
| `REASON` | VARCHAR2(500) | Yes | — | — | Employee-provided reason |
| `APPROVER_EMP_ID` | NUMBER(10) | Yes | — | **FK → EMPLOYEES** | Manager who approved/rejected |
| `APPROVAL_DATE` | DATE | Yes | — | — | When approved/rejected |
| `APPROVAL_COMMENTS` | VARCHAR2(500) | Yes | — | — | Approver comments |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Triggers:** `TRG_LEAVE_REQ_BEFORE_INSERT` — auto-generates ID, sets PENDING status

---

### 4.4 LEAVE_ACCRUAL_LOG

> **Business Purpose:** Audit trail for monthly accrual batch job. One row per employee per leave type per accrual run.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `ACCRUAL_ID` | NUMBER(10) | No | `SEQ_LEAVE_ACCRUAL.NEXTVAL` | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Employee |
| `LEAVE_TYPE_ID` | NUMBER(10) | No | — | **FK → LEAVE_TYPES** | Leave type |
| `ACCRUAL_DATE` | DATE | No | — | — | Date of accrual |
| `ACCRUAL_AMOUNT` | NUMBER(5,3) | No | — | — | Days accrued |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 4.5 HOLIDAYS

> **Business Purpose:** Company holiday calendar used by `PKG_COMMON.business_days_between` and `PKG_LEAVE.calculate_business_days`.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `HOLIDAY_ID` | NUMBER(10) | No | `SEQ_HOLIDAY.NEXTVAL` | **PK** | Surrogate key |
| `HOLIDAY_DATE` | DATE | No | — | — | Date of holiday |
| `HOLIDAY_NAME` | VARCHAR2(100) | No | — | — | Holiday name |
| `COUNTRY_CODE` | VARCHAR2(3) | No | `'US'` | — | Applicable country |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

## 5. Performance Management Domain

### 5.1 REVIEW_CYCLES

> **Business Purpose:** Defines performance review periods (typically annual). Controls the lifecycle: DRAFT → OPEN → CLOSED.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `CYCLE_ID` | NUMBER(10) | No | `SEQ_REVIEW_CYCLE.NEXTVAL` | **PK** | Surrogate key |
| `CYCLE_NAME` | VARCHAR2(100) | No | — | — | Display name |
| `CYCLE_YEAR` | NUMBER(4) | No | — | — | Review year |
| `START_DATE` | DATE | No | — | — | Cycle start |
| `END_DATE` | DATE | No | — | — | Cycle end |
| `STATUS` | VARCHAR2(20) | No | `'DRAFT'` | `CHECK IN ('DRAFT','OPEN','CLOSED')` | Cycle status |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

### 5.2 PERFORMANCE_REVIEWS

> **Business Purpose:** Individual employee reviews within a cycle. Tracks the full workflow from PENDING through self-assessment, manager review, to acknowledgment.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `REVIEW_ID` | NUMBER(10) | No | `SEQ_PERFORMANCE_REVIEW.NEXTVAL` | **PK** | Surrogate key |
| `CYCLE_ID` | NUMBER(10) | No | — | **FK → REVIEW_CYCLES** | Parent cycle |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Reviewed employee |
| `REVIEWER_EMP_ID` | NUMBER(10) | Yes | — | **FK → EMPLOYEES** | Reviewing manager |
| `STATUS` | VARCHAR2(20) | No | `'PENDING'` | `CHECK IN ('PENDING','SELF_ASSESSMENT','MANAGER_REVIEW','COMPLETED','ACKNOWLEDGED')` | Workflow status |
| `SELF_ASSESSMENT` | CLOB | Yes | — | — | Employee self-assessment text |
| `MANAGER_ASSESSMENT` | CLOB | Yes | — | — | Manager assessment text |
| `OVERALL_RATING` | NUMBER(3,1) | Yes | — | — | Numeric rating (1.0 – 5.0) |
| `RATING_LABEL` | VARCHAR2(50) | Yes | — | — | Text label for rating |
| `ACKNOWLEDGED_DATE` | DATE | Yes | — | — | When employee acknowledged |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Triggers:** `TRG_REVIEW_BEFORE_INSERT` — auto-generates ID, sets PENDING status

---

### 5.3 PERFORMANCE_GOALS

> **Business Purpose:** Individual goals linked to a performance review. Supports weighted goals with progress tracking.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `GOAL_ID` | NUMBER(10) | No | `SEQ_PERFORMANCE_GOAL.NEXTVAL` | **PK** | Surrogate key |
| `REVIEW_ID` | NUMBER(10) | No | — | **FK → PERFORMANCE_REVIEWS** | Parent review |
| `GOAL_TITLE` | VARCHAR2(200) | No | — | — | Goal description |
| `GOAL_DESCRIPTION` | CLOB | Yes | — | — | Detailed description |
| `GOAL_CATEGORY` | VARCHAR2(20) | No | — | `CHECK IN ('BUSINESS','DEVELOPMENT','LEADERSHIP')` | Category |
| `WEIGHT_PCT` | NUMBER(5,2) | Yes | — | — | Weight percentage (should sum to 100%) |
| `TARGET_DATE` | DATE | Yes | — | — | Expected completion date |
| `PROGRESS_PCT` | NUMBER(5,2) | No | `0` | — | Progress percentage |
| `STATUS` | VARCHAR2(20) | No | `'NOT_STARTED'` | `CHECK IN ('NOT_STARTED','IN_PROGRESS','COMPLETED','CANCELLED')` | Goal status |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

---

## 6. System & Audit Domain

### 6.1 AUDIT_LOG

> **Business Purpose:** System-wide audit trail recording all significant DML operations. Populated by triggers and `PKG_AUDIT.log_change` (via autonomous transactions).

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `AUDIT_ID` | NUMBER(10) | No | `SEQ_AUDIT_LOG.NEXTVAL` | **PK** | Surrogate key |
| `TABLE_NAME` | VARCHAR2(30) | No | — | — | Affected table |
| `OPERATION` | VARCHAR2(10) | No | — | — | INSERT, UPDATE, DELETE |
| `RECORD_ID` | NUMBER(10) | Yes | — | — | PK of affected record |
| `OLD_VALUES` | CLOB | Yes | — | — | JSON/text of previous values |
| `NEW_VALUES` | CLOB | Yes | — | — | JSON/text of new values |
| `CHANGED_BY` | VARCHAR2(30) | No | — | — | Username |
| `CHANGE_DATE` | DATE | No | `SYSDATE` | — | Timestamp |
| `MODULE_NAME` | VARCHAR2(100) | Yes | — | — | Source module |
| `IP_ADDRESS` | VARCHAR2(45) | Yes | — | — | Client IP |

**Triggers:** `TRG_AUDIT_LOG_BEFORE_INSERT` — auto-generates ID

---

### 6.2 SYSTEM_PARAMETERS

> **Business Purpose:** Application configuration key-value store. Accessed via `PKG_COMMON.get_param` / `set_param`. Contains integration credentials, SMTP settings, and other runtime configuration.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `PARAM_CATEGORY` | VARCHAR2(50) | No | — | **PK (composite)** | Category grouping |
| `PARAM_NAME` | VARCHAR2(50) | No | — | **PK (composite)** | Parameter name |
| `PARAM_VALUE` | VARCHAR2(500) | Yes | — | — | Parameter value |
| `DESCRIPTION` | VARCHAR2(200) | Yes | — | — | Human-readable description |
| `MODIFIED_BY` | VARCHAR2(30) | Yes | — | — | |
| `MODIFIED_DATE` | DATE | Yes | — | — | |

**Security Note:** FTP credentials are stored in cleartext in this table.

---

### 6.3 NOTIFICATION_QUEUE

> **Business Purpose:** Async notification queue for email, SMS, and in-app messages. Processed by `PKG_NOTIFICATION.process_queue`.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `NOTIFICATION_ID` | NUMBER(10) | No | `SEQ_NOTIFICATION.NEXTVAL` | **PK** | Surrogate key |
| `NOTIFICATION_TYPE` | VARCHAR2(20) | No | — | — | EMAIL, SMS, IN_APP |
| `RECIPIENT_EMP_ID` | NUMBER(10) | Yes | — | **FK → EMPLOYEES** | Target employee |
| `RECIPIENT_EMAIL` | VARCHAR2(100) | Yes | — | — | Email address |
| `SUBJECT` | VARCHAR2(200) | Yes | — | — | Message subject |
| `BODY` | CLOB | Yes | — | — | Message body |
| `STATUS` | VARCHAR2(20) | No | `'PENDING'` | `CHECK IN ('PENDING','SENT','FAILED','CANCELLED')` | Queue status |
| `PRIORITY` | NUMBER(2) | No | `5` | — | Priority (1=highest) |
| `SEND_DATE` | DATE | Yes | — | — | When sent |
| `ERROR_MESSAGE` | VARCHAR2(500) | Yes | — | — | Error details if failed |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |
| `CREATED_DATE` | DATE | No | `SYSDATE` | — | |

**Triggers:** `TRG_NOTIFICATION_BEFORE_INSERT` — auto-generates ID

---

### 6.4 USER_SESSIONS

> **Business Purpose:** Active user session tracking for authentication and timeout management. Managed by `PKG_SECURITY`.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `SESSION_ID` | NUMBER(10) | No | — | **PK** | Surrogate key |
| `EMP_ID` | NUMBER(10) | No | — | **FK → EMPLOYEES** | Logged-in employee |
| `LOGIN_TIME` | DATE | No | `SYSDATE` | — | Login timestamp |
| `LOGOUT_TIME` | DATE | Yes | — | — | Logout timestamp (NULL = active) |
| `IP_ADDRESS` | VARCHAR2(45) | Yes | — | — | Client IP address |
| `STATUS` | VARCHAR2(20) | No | `'ACTIVE'` | `CHECK IN ('ACTIVE','EXPIRED','LOGGED_OUT')` | Session state |
| `LAST_ACTIVITY` | DATE | Yes | — | — | Last interaction timestamp |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |

---

### 6.5 LOOKUP_VALUES

> **Business Purpose:** Generic lookup/reference data table for drop-down lists and code translations.

| Column | Data Type | Nullable | Default | Constraints | Description |
|--------|-----------|----------|---------|-------------|-------------|
| `LOOKUP_TYPE` | VARCHAR2(30) | No | — | **PK (composite)** | Lookup category |
| `LOOKUP_CODE` | VARCHAR2(30) | No | — | **PK (composite)** | Code value |
| `LOOKUP_DISPLAY` | VARCHAR2(100) | No | — | — | Display value |
| `SORT_ORDER` | NUMBER(5) | Yes | — | — | Display order |
| `ACTIVE_FLAG` | CHAR(1) | No | `'Y'` | — | |
| `CREATED_BY` | VARCHAR2(30) | No | — | — | |

---

## 7. Reporting Views

| View | Source Tables | Business Purpose |
|------|-------------|-----------------|
| `VW_ACTIVE_EMPLOYEES` | EMPLOYEES, DEPARTMENTS, JOB_TITLES, JOB_GRADES, LOCATIONS | Denormalized view of all active employees with department, job, grade, and location details. Used as base for most reports and as the target for the `INSTEAD OF DELETE` soft-delete trigger. |
| `VW_ORG_HIERARCHY` | EMPLOYEES | Hierarchical org chart using `CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID`. Includes `LEVEL`, `SYS_CONNECT_BY_PATH`, and `MANAGER_NAME`. |
| `VW_EMPLOYEE_COMPENSATION` | EMPLOYEES, SALARY_RECORDS, JOB_GRADES | Current compensation with grade range (min/max) and compa-ratio calculation. Only includes active employees with active salary records. |
| `VW_LEAVE_SUMMARY` | LEAVE_BALANCES, LEAVE_TYPES, EMPLOYEES | Current year leave balances with available balance calculation for active employees. |
| `VW_PAYROLL_LATEST` | PAYROLL_DETAILS, PAYROLL_RUNS, PAY_PERIODS, PAY_ELEMENTS, EMPLOYEES | Latest payroll run details per employee including earnings, deductions, and net pay. |
| `VW_PENDING_APPROVALS` | LEAVE_REQUESTS, EMPLOYEES, LEAVE_TYPES | Pending leave requests with employee name and leave type name for the approval queue. |

---

## 8. Cross-Domain Relationships

```
                    ┌──────────────┐
                    │  LOCATIONS   │
                    └──────┬───────┘
                           │ LOCATION_CODE
                    ┌──────┴───────┐
         ┌──────────┤ DEPARTMENTS  ├──────────┐
         │ PARENT   └──────┬───────┘ MANAGER  │
         │ DEPT_ID         │ DEPT_ID  EMP_ID  │
         └─────────┐       │         ┌────────┘
                   │  ┌────┴─────┐   │
                   └──┤EMPLOYEES ├───┘
           ┌──────────┤          ├──────────┐
           │  EMP_ID  │          │  EMP_ID  │
           │          └──┬───┬───┘          │
           │      JOB_ID │   │ MANAGER      │
    ┌──────┴──────┐      │   │ (self-ref)   │
    │  SALARY_    │  ┌───┴───┴──┐    ┌──────┴──────┐
    │  RECORDS    │  │JOB_TITLES│    │  LEAVE_     │
    └─────────────┘  └────┬─────┘    │  REQUESTS   │
                   GRADE  │          └─────────────┘
                   _ID    │
                  ┌───────┴──┐
                  │JOB_GRADES│
                  └──────────┘
```

**Key Foreign Key Chains:**

1. `EMPLOYEES.DEPT_ID → DEPARTMENTS.DEPT_ID → LOCATIONS.LOCATION_CODE`
2. `EMPLOYEES.JOB_ID → JOB_TITLES.JOB_ID → JOB_GRADES.GRADE_ID`
3. `EMPLOYEES.MANAGER_EMP_ID → EMPLOYEES.EMP_ID` (self-referencing hierarchy)
4. `SALARY_RECORDS.EMP_ID → EMPLOYEES.EMP_ID`
5. `LEAVE_REQUESTS.EMP_ID → EMPLOYEES.EMP_ID`
6. `LEAVE_REQUESTS.LEAVE_TYPE_ID → LEAVE_TYPES.LEAVE_TYPE_ID`
7. `PAYROLL_DETAILS.RUN_ID → PAYROLL_RUNS.RUN_ID → PAY_PERIODS.PERIOD_ID`
8. `PERFORMANCE_REVIEWS.CYCLE_ID → REVIEW_CYCLES.CYCLE_ID`
9. `PERFORMANCE_GOALS.REVIEW_ID → PERFORMANCE_REVIEWS.REVIEW_ID`
