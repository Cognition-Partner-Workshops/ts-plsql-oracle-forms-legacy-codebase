# Application Inventory

> **System**: HRMS (Human Resource Management System) v4.2  
> **Platform**: Oracle Forms 12c (12.2.1.4) / Oracle Database 19c  
> **Schema**: HRMS  
> **Estimated Size**: ~7 000 lines SQL/PL/SQL, ~1 400 lines Forms XML, 40 files  

---

## 1. Oracle Forms Modules (Presentation Layer)

All Forms XML exports reside in `forms/xml-exports/`. Each `.xml` file is an XML export of a binary `.fmb` module.

| # | Module Name | File | Purpose | Canvases / Tab Pages | Data Blocks | LOVs | Attached Libraries | Menu Module |
|---|-------------|------|---------|----------------------|-------------|------|--------------------|-------------|
| 1 | HRMS_LOGIN | `HRMS_LOGIN.xml` (131 lines) | Authentication & session creation | 1 Content canvas (`CVS_LOGIN`) | 1 (`LOGIN` - non-DB control block) | 0 | None | None |
| 2 | HRMS_MENU | `HRMS_MENU.xml` (176 lines) | MDI parent / main navigation shell | 1 Content canvas (`CVS_MAIN`) | 1 (`MENU_CONTROL` - non-DB control block) | 0 | HRMS_COMMON_LIB | MENU_MAIN (inline) |
| 3 | HRMS_EMPLOYEE | `HRMS_EMPLOYEE.xml` (539 lines) | Employee maintenance (master-detail) | 1 Tab canvas with 4 pages (Personal, Job & Compensation, Dependents, History) + 1 Toolbar | 2+ (`EMPLOYEE` on EMPLOYEES table, `SALARY` on SALARY_RECORDS) | 4 (Departments, Job Titles, Managers, Locations) | HRMS_COMMON_LIB, HRMS_VALIDATION_LIB | HRMS_MENU (file) |
| 4 | HRMS_PAYROLL | `HRMS_PAYROLL.xml` (167 lines) | Payroll processing & approval | 1 Tab canvas with 3 pages (Pay Periods, Payroll Runs, Pay Details) | 2+ (`PAY_PERIOD`, `PAYROLL_RUN`) | 3 (Period, Run Type, Employee) | HRMS_COMMON_LIB | HRMS_MENU (file) |
| 5 | HRMS_LEAVE | `HRMS_LEAVE.xml` (220 lines) | Leave requests, approvals, balances | 1 Tab canvas with 4 pages (My Requests, Submit Request, Approvals, Team Calendar) | 4 (`LEAVE_REQUEST`, `NEW_REQUEST`, `LEAVE_BALANCE`, `PENDING_APPROVAL`) | 1 (Leave Type) | HRMS_COMMON_LIB | HRMS_MENU (file) |
| 6 | HRMS_PERFORMANCE | `HRMS_PERFORMANCE.xml` (132 lines) | Performance reviews & goals | 1 Tab canvas with 3 pages (Review Cycles, My Reviews, Goals) | 3 (`REVIEW_CYCLE`, `PERFORMANCE_REVIEW`, `PERFORMANCE_GOAL`) | 0 | HRMS_COMMON_LIB | HRMS_MENU (file) |

### Common Form-Level Triggers

| Trigger | Present In | Purpose |
|---------|-----------|---------|
| `WHEN-NEW-FORM-INSTANCE` | All 6 forms | Session validation via `PKG_SECURITY.is_session_valid`, permission checks, LOV initialization, default WHERE clause |
| `ON-ERROR` | HRMS_EMPLOYEE | Suppresses benign errors (40202, 40401), user-friendly lock messages (40501) |
| `KEY-EXIT` | HRMS_EMPLOYEE | Unsaved-changes prompt with Save/Discard/Cancel |
| `PRE-INSERT` | HRMS_EMPLOYEE | Generates `EMP_ID` (sequence), `EMP_NUMBER` (`PKG_EMPLOYEE.generate_emp_number`), sets audit columns |
| `PRE-UPDATE` | HRMS_EMPLOYEE | Sets `MODIFIED_BY` / `MODIFIED_DATE` |
| `POST-QUERY` | HRMS_EMPLOYEE, HRMS_LEAVE, HRMS_PERFORMANCE | Populates display-only items (dept name, manager name, leave type name, employee name) |
| `WHEN-VALIDATE-ITEM` | HRMS_EMPLOYEE | Client-side validation for email, hire date, department, job title |
| `WHEN-BUTTON-PRESSED` | All forms (various buttons) | Action handlers: login, create run, calculate payroll, approve, submit leave, cancel request |

---

## 2. PL/SQL Libraries (Shared Client-Side Code)

Libraries reside in `forms/libraries/`. These are `.pll` source exports.

| # | Library Name | File | Lines | Purpose | Key Procedures / Functions | Called By |
|---|-------------|------|-------|---------|---------------------------|-----------|
| 1 | HRMS_COMMON_LIB | `HRMS_COMMON_LIB.pll.sql` | ~220 | Shared toolbar, error handling, session management, date formatting, LOV refresh | `handle_error`, `toolbar_save/clear/query/insert/delete/exit`, `navigate_first/prev/next/last`, `format_date_display`, `check_session`, `refresh_lov` | All forms except HRMS_LOGIN |
| 2 | HRMS_VALIDATION_LIB | `HRMS_VALIDATION_LIB.pll.sql` | ~150 | Client-side field validation | `validate_email`, `validate_phone`, `validate_ssn`, `validate_date_not_future`, `validate_salary_range` | HRMS_EMPLOYEE |

### Library Attachment Matrix

| Form Module | HRMS_COMMON_LIB | HRMS_VALIDATION_LIB |
|-------------|:---------------:|:-------------------:|
| HRMS_LOGIN | - | - |
| HRMS_MENU | Attached | - |
| HRMS_EMPLOYEE | Attached | Attached |
| HRMS_PAYROLL | Attached | - |
| HRMS_LEAVE | Attached | - |
| HRMS_PERFORMANCE | Attached | - |

---

## 3. Menu Module

| # | Module Name | File | Location | Purpose |
|---|-------------|------|----------|---------|
| 1 | HRMS_MENU | `forms/menus/HRMS_MENU.mmb.sql` | `forms/menus/` | Role-based navigation; inline menu definition also in `HRMS_MENU.xml` |

### Menu Structure

```
MENU_MAIN
  +-- File
  |     +-- Logout
  +-- Modules
  |     +-- Employee Management  -> HRMS_EMPLOYEE
  |     +-- Payroll Processing   -> HRMS_PAYROLL
  |     +-- Leave Management     -> HRMS_LEAVE
  |     +-- Performance Reviews  -> HRMS_PERFORMANCE
  |     +-- Reports              -> HRMS_REPORTS
  +-- Admin
  |     +-- System Administration -> HRMS_ADMIN
  |     +-- Change Password       -> WIN_CHANGE_PWD
  +-- Help
        +-- About HRMS  (v4.2 - Build 2024.03.15)
```

Menu items are enabled/disabled at runtime using `PKG_SECURITY.has_permission()` based on user's grade level.

---

## 4. PL/SQL Packages (Business Logic Layer)

All packages reside in `plsql/packages/`. Each package has a `.pks` (specification) and `.pkb` (body).

| # | Package Name | Spec (lines) | Body (lines) | Layer | Purpose | Key Procedures / Functions |
|---|-------------|:------------:|:------------:|-------|---------|---------------------------|
| 1 | PKG_COMMON | 122 | 284 | Infrastructure | Logging, date utilities, formatting, config parameters | `log_error`, `log_info`, `get_param`, `set_param`, `business_days_between`, `add_business_days`, `get_fiscal_year`, `format_phone`, `format_ssn_masked`, `is_valid_email`, `is_valid_phone` |
| 2 | PKG_AUDIT | 33 | 73 | Infrastructure | Centralized audit trail | `log_action`, `purge_old_records`, `get_change_history` |
| 3 | PKG_VALIDATION | 48 | 126 | Infrastructure | Server-side business rule validation | `validate_date_range`, `validate_salary_for_grade`, `validate_email_format`, `validate_phone_format`, `validate_emp_number_format`, `is_future_date`, `is_business_day`, `validate_required_fields` |
| 4 | PKG_NOTIFICATION | 43 | 178 | Infrastructure | Email/SMS/in-app notification queue | `send_notification`, `process_queue`, `retry_failed`, `cancel_notification` |
| 5 | PKG_SECURITY | 64 | 238 | Infrastructure | Authentication, sessions, RBAC, encryption | `authenticate`, `logout`, `is_session_valid`, `has_permission`, `encrypt_ssn`, `decrypt_ssn`, `hash_password`, `change_password` |
| 6 | PKG_EMPLOYEE | 193 | 967 | Domain - Core HR | Employee CRUD, lifecycle, org chart | `create_employee`, `update_employee`, `get_employee`, `search_employees`, `transfer_employee`, `promote_employee`, `terminate_employee`, `rehire_employee`, `get_org_chart`, `generate_emp_number` |
| 7 | PKG_PAYROLL | 165 | 898 | Domain - Payroll | Salary management, pay runs, tax calculation | `create_salary_record`, `create_payroll_run`, `calculate_payroll`, `calculate_employee_pay`, `approve_payroll`, `reverse_payroll`, `calculate_federal_tax`, `calculate_state_tax`, `calculate_fica`, `calculate_medicare`, `get_payslip`, `generate_pay_register` |
| 8 | PKG_LEAVE | 129 | 674 | Domain - Leave | Leave requests, approvals, balances, accrual | `submit_leave_request`, `approve_leave_request`, `reject_leave_request`, `cancel_leave_request`, `get_leave_balance`, `run_monthly_accrual`, `process_carryover`, `expire_carryover`, `get_team_calendar` |
| 9 | PKG_PERFORMANCE | 98 | 321 | Domain - Performance | Review cycles, goals, ratings | `create_review_cycle`, `open_review_cycle`, `close_review_cycle`, `create_review`, `submit_self_assessment`, `submit_manager_review`, `acknowledge_review`, `add_goal`, `update_goal_progress`, `generate_reviews_for_cycle` |
| 10 | PKG_REPORTING | 64 | 208 | Reporting | Headcount, compensation, turnover, compliance | `headcount_report`, `compensation_summary`, `turnover_report`, `new_hires_report`, `leave_utilization_report`, `payroll_summary_report`, `eeo_compliance_report`, `refresh_reporting_tables` |
| 11 | PKG_INTEGRATION | 51 | 214 | Integration | GL journal, benefits feed, time import | `generate_gl_journal`, `export_benefits_feed`, `import_time_attendance`, `sync_org_structure`, `get_integration_status` |

### Package Layer Classification

```
+--------------------------------------------------+
|  PRESENTATION LAYER (Oracle Forms 12c)           |
|  6 Forms + 2 PLL Libraries + 1 Menu Module       |
+--------------------------------------------------+
            |
            v
+--------------------------------------------------+
|  BUSINESS LOGIC LAYER (PL/SQL Packages)          |
|                                                  |
|  Infrastructure:                                 |
|    PKG_COMMON, PKG_AUDIT, PKG_VALIDATION,        |
|    PKG_NOTIFICATION, PKG_SECURITY                |
|                                                  |
|  Domain:                                         |
|    PKG_EMPLOYEE, PKG_PAYROLL, PKG_LEAVE,         |
|    PKG_PERFORMANCE                               |
|                                                  |
|  Reporting:                                      |
|    PKG_REPORTING                                 |
|                                                  |
|  Integration:                                    |
|    PKG_INTEGRATION                               |
+--------------------------------------------------+
            |
            v
+--------------------------------------------------+
|  DATA LAYER (Oracle 19c)                         |
|  30 Tables, 6 Views, 25 Sequences, 6 Triggers   |
+--------------------------------------------------+
```

---

## 5. Database Triggers

Triggers reside in `plsql/triggers/`.

| # | Trigger Name | File | Timing | Table | Purpose |
|---|-------------|------|--------|-------|---------|
| 1 | TRG_EMP_BEFORE_INSERT | `trg_employees.sql` | BEFORE INSERT | EMPLOYEES | Auto-generates `EMP_ID` from sequence, sets `ACTIVE_FLAG`, `EMPLOYMENT_STATUS`, audit columns |
| 2 | TRG_EMP_BEFORE_UPDATE | `trg_employees.sql` | BEFORE UPDATE | EMPLOYEES | Sets `MODIFIED_BY` / `MODIFIED_DATE`, logs status changes to EMPLOYEE_HISTORY |
| 3 | TRG_EMP_INSTEAD_OF_DELETE | `trg_employees.sql` | INSTEAD OF DELETE | EMPLOYEES | Converts DELETE to soft delete (`ACTIVE_FLAG := 'N'`); Forms must use `SET ACTIVE_FLAG='N'` + `CLEAR_RECORD` workaround |
| 4 | TRG_SALARY_AUDIT | `trg_audit.sql` | AFTER INSERT OR UPDATE | SALARY_RECORDS | Calls `PKG_AUDIT.log_action` for salary change tracking |
| 5 | TRG_LEAVE_REQUEST_AUDIT | `trg_audit.sql` | AFTER INSERT OR UPDATE | LEAVE_REQUESTS | Calls `PKG_AUDIT.log_action` for leave request tracking |
| 6 | TRG_DEPARTMENT_AUDIT | `trg_audit.sql` | AFTER INSERT OR UPDATE OR DELETE | DEPARTMENTS | Calls `PKG_AUDIT.log_action` for department change tracking |

---

## 6. Database Views

Views reside in `schema/views/hrms_views.sql`.

| # | View Name | Source Tables | Purpose |
|---|-----------|---------------|---------|
| 1 | VW_ACTIVE_EMPLOYEES | EMPLOYEES, DEPARTMENTS, JOB_TITLES, JOB_GRADES, LOCATIONS | Denormalized active employee roster with department, job, grade, and location details |
| 2 | VW_ORG_HIERARCHY | EMPLOYEES, JOB_TITLES | Hierarchical org chart using `CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID` |
| 3 | VW_EMPLOYEE_COMPENSATION | EMPLOYEES, SALARY_RECORDS, JOB_GRADES, DEPARTMENTS | Current compensation with compa-ratio calculation (`BASE_SALARY / MIDPOINT`) |
| 4 | VW_LEAVE_SUMMARY | LEAVE_BALANCES, LEAVE_TYPES, EMPLOYEES | Current-year leave balance summary per employee and leave type |
| 5 | VW_PAYROLL_LATEST | PAYROLL_RUNS, PAY_PERIODS, PAYROLL_DETAILS | Latest payroll run with gross/deduction/net totals |
| 6 | VW_PENDING_APPROVALS | LEAVE_REQUESTS, EMPLOYEES, LEAVE_TYPES | Pending leave requests with employee and type details for approver dashboards |

---

## 7. Schema Objects

### 7a. Tables (30 tables across 4 DDL files in `schema/tables/`)

#### Core Tables (`01_core_tables.sql`) - 8 tables

| # | Table | Key Columns | Notes |
|---|-------|-------------|-------|
| 1 | DEPARTMENTS | DEPT_ID (PK), DEPT_CODE, DEPT_NAME, COST_CENTER, PARENT_DEPT_ID (self-ref FK) | Hierarchical via PARENT_DEPT_ID |
| 2 | LOCATIONS | LOCATION_CODE (PK), LOCATION_NAME, CITY, STATE_PROVINCE, COUNTRY_CODE | Reference data |
| 3 | JOB_GRADES | GRADE_ID (PK), GRADE_NAME, GRADE_LEVEL, MIN_SALARY, MAX_SALARY | 10 grades (Entry Level through C-Suite) |
| 4 | JOB_TITLES | JOB_ID (PK), JOB_CODE, JOB_TITLE, GRADE_ID (FK), EEO_CATEGORY | 26 job titles |
| 5 | EMPLOYEES | EMP_ID (PK), EMP_NUMBER (unique), FIRST_NAME, LAST_NAME, EMAIL, HIRE_DATE, DEPT_ID (FK), JOB_ID (FK), MANAGER_EMP_ID (self-ref FK) | Central entity; soft delete via ACTIVE_FLAG |
| 6 | EMPLOYEE_HISTORY | HISTORY_ID (PK), EMP_ID (FK), CHANGE_TYPE, OLD_VALUE, NEW_VALUE | Change tracking for employee lifecycle events |
| 7 | EMPLOYEE_DEPENDENTS | DEPENDENT_ID (PK), EMP_ID (FK), FIRST_NAME, LAST_NAME, RELATIONSHIP, DATE_OF_BIRTH | Benefits enrollment dependents |
| 8 | EMERGENCY_CONTACTS | CONTACT_ID (PK), EMP_ID (FK), CONTACT_NAME, RELATIONSHIP, PHONE | Emergency contact information |

#### Payroll Tables (`02_payroll_tables.sql`) - 9 tables

| # | Table | Key Columns | Notes |
|---|-------|-------------|-------|
| 9 | SALARY_RECORDS | SALARY_ID (PK), EMP_ID (FK), BASE_SALARY, EFFECTIVE_DATE, END_DATE, CHANGE_REASON | Active record pattern (ACTIVE_FLAG = 'Y') |
| 10 | PAY_ELEMENTS | ELEMENT_ID (PK), ELEMENT_CODE, ELEMENT_TYPE, CALCULATION_TYPE, GL_ACCOUNT_CODE | Earnings, deductions, taxes, benefits definitions |
| 11 | EMPLOYEE_PAY_ELEMENTS | EPE_ID (PK), EMP_ID (FK), ELEMENT_ID (FK), AMOUNT, PERCENTAGE | Per-employee pay element assignments |
| 12 | PAY_PERIODS | PERIOD_ID (PK), PERIOD_NAME, PERIOD_START_DATE, PERIOD_END_DATE, PAY_DATE, STATUS | Monthly/biweekly pay periods |
| 13 | PAYROLL_RUNS | RUN_ID (PK), PERIOD_ID (FK), RUN_TYPE, STATUS, EMPLOYEE_COUNT, TOTAL_GROSS, TOTAL_NET | Payroll batch run header |
| 14 | PAYROLL_DETAILS | DETAIL_ID (PK), RUN_ID (FK), EMP_ID (FK), ELEMENT_ID (FK), AMOUNT, STATUS | Per-employee per-element payroll line items |
| 15 | TAX_BRACKETS | BRACKET_ID (PK), TAX_YEAR, FILING_STATUS, MIN_INCOME, MAX_INCOME, TAX_RATE | Federal/state tax brackets (currently hard-coded in PKG_PAYROLL) |
| 16 | EMPLOYEE_TAX_INFO | TAX_INFO_ID (PK), EMP_ID (FK), TAX_YEAR, FILING_STATUS, ALLOWANCES, STATE_CODE | W-4 withholding information |
| 17 | EMPLOYEE_BANK_ACCOUNTS | BANK_ACCOUNT_ID (PK), EMP_ID (FK), BANK_NAME, ACCOUNT_NUMBER_ENC, ROUTING_NUMBER | Direct deposit; account number encrypted |

#### Leave Tables (`03_leave_tables.sql`) - 5 tables

| # | Table | Key Columns | Notes |
|---|-------|-------------|-------|
| 18 | LEAVE_TYPES | LEAVE_TYPE_ID (PK), LEAVE_TYPE_CODE, ACCRUAL_FLAG, ACCRUAL_RATE, MAX_BALANCE, CARRYOVER_MAX | 5 types: PTO, Sick, Comp, FMLA, Jury Duty |
| 19 | LEAVE_BALANCES | BALANCE_ID (PK), EMP_ID (FK), LEAVE_TYPE_ID (FK), CALENDAR_YEAR, OPENING_BALANCE, ACCRUED, USED, PENDING, AVAILABLE (virtual) | Virtual column: `OPENING_BALANCE + ACCRUED - USED + ADJUSTMENT` |
| 20 | LEAVE_REQUESTS | REQUEST_ID (PK), EMP_ID (FK), LEAVE_TYPE_ID (FK), START_DATE, END_DATE, TOTAL_DAYS, STATUS, HALF_DAY_FLAG | Workflow: PENDING -> APPROVED/REJECTED -> TAKEN/CANCELLED |
| 21 | LEAVE_ACCRUAL_LOG | ACCRUAL_ID (PK), EMP_ID (FK), LEAVE_TYPE_ID (FK), ACCRUAL_DATE, ACCRUAL_AMOUNT | Monthly accrual batch log |
| 22 | HOLIDAYS | HOLIDAY_ID (PK), HOLIDAY_DATE, HOLIDAY_NAME, COUNTRY_CODE | Company-observed holidays |

#### Performance & System Tables (`04_performance_tables.sql`) - 8 tables

| # | Table | Key Columns | Notes |
|---|-------|-------------|-------|
| 23 | REVIEW_CYCLES | CYCLE_ID (PK), CYCLE_NAME, CYCLE_YEAR, START_DATE, END_DATE, STATUS | Annual review cycle management |
| 24 | PERFORMANCE_REVIEWS | REVIEW_ID (PK), CYCLE_ID (FK), EMP_ID (FK), REVIEWER_EMP_ID (FK), OVERALL_RATING, STATUS | Workflow: NOT_STARTED -> SELF_REVIEW -> MANAGER_REVIEW -> COMPLETED -> ACKNOWLEDGED |
| 25 | PERFORMANCE_GOALS | GOAL_ID (PK), REVIEW_ID (FK), EMP_ID (FK), GOAL_TITLE, WEIGHT_PCT, PROGRESS_PCT, STATUS | Goal categories: BUSINESS, DEVELOPMENT, LEADERSHIP |
| 26 | AUDIT_LOG | LOG_ID (PK), TABLE_NAME, RECORD_ID, ACTION, PERFORMED_BY, IP_ADDRESS, SESSION_ID | Cross-cutting audit trail for all DML |
| 27 | SYSTEM_PARAMETERS | PARAM_ID (PK), PARAM_CATEGORY, PARAM_NAME, PARAM_VALUE | Application configuration key-value store |
| 28 | NOTIFICATION_QUEUE | NOTIFICATION_ID (PK), RECIPIENT_EMP_ID (FK), TYPE, SUBJECT, BODY, STATUS, RETRY_COUNT | Async notification processing: PENDING -> SENT/FAILED |
| 29 | USER_SESSIONS | SESSION_ID (PK), EMP_ID (FK), LOGIN_TIME, LOGOUT_TIME, IP_ADDRESS, SESSION_STATUS | Active session tracking |
| 30 | LOOKUP_VALUES | LOOKUP_ID (PK), LOOKUP_TYPE, LOOKUP_CODE, LOOKUP_VALUE, DISPLAY_ORDER | Generic code-description lookup table |

### 7b. Sequences (`schema/sequences/hrms_sequences.sql`) - 25 sequences

All sequences use `START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE`.

| # | Sequence Name | Target Table |
|---|--------------|-------------|
| 1 | SEQ_EMPLOYEE | EMPLOYEES.EMP_ID |
| 2 | SEQ_EMP_NUMBER | Employee number generation (MAX+1 pattern - see Technical Debt) |
| 3 | SEQ_DEPARTMENT | DEPARTMENTS.DEPT_ID |
| 4 | SEQ_JOB_TITLE | JOB_TITLES.JOB_ID |
| 5 | SEQ_JOB_GRADE | JOB_GRADES.GRADE_ID |
| 6 | SEQ_LOCATION | LOCATIONS.LOCATION_CODE generation |
| 7 | SEQ_EMP_HISTORY | EMPLOYEE_HISTORY.HISTORY_ID |
| 8 | SEQ_DEPENDENT | EMPLOYEE_DEPENDENTS.DEPENDENT_ID |
| 9 | SEQ_EMERGENCY | EMERGENCY_CONTACTS.CONTACT_ID |
| 10 | SEQ_SALARY | SALARY_RECORDS.SALARY_ID |
| 11 | SEQ_PAY_ELEMENT | PAY_ELEMENTS.ELEMENT_ID |
| 12 | SEQ_EMP_PAY_ELEMENT | EMPLOYEE_PAY_ELEMENTS.EPE_ID |
| 13 | SEQ_PAY_PERIOD | PAY_PERIODS.PERIOD_ID |
| 14 | SEQ_PAYROLL_RUN | PAYROLL_RUNS.RUN_ID |
| 15 | SEQ_PAYROLL_DETAIL | PAYROLL_DETAILS.DETAIL_ID |
| 16 | SEQ_TAX_BRACKET | TAX_BRACKETS.BRACKET_ID |
| 17 | SEQ_TAX_INFO | EMPLOYEE_TAX_INFO.TAX_INFO_ID |
| 18 | SEQ_BANK_ACCOUNT | EMPLOYEE_BANK_ACCOUNTS.BANK_ACCOUNT_ID |
| 19 | SEQ_LEAVE_TYPE | LEAVE_TYPES.LEAVE_TYPE_ID |
| 20 | SEQ_LEAVE_BALANCE | LEAVE_BALANCES.BALANCE_ID |
| 21 | SEQ_LEAVE_REQUEST | LEAVE_REQUESTS.REQUEST_ID |
| 22 | SEQ_LEAVE_ACCRUAL | LEAVE_ACCRUAL_LOG.ACCRUAL_ID |
| 23 | SEQ_REVIEW_CYCLE | REVIEW_CYCLES.CYCLE_ID |
| 24 | SEQ_PERF_REVIEW | PERFORMANCE_REVIEWS.REVIEW_ID |
| 25 | SEQ_PERF_GOAL | PERFORMANCE_GOALS.GOAL_ID |

### 7c. Seed Data (`data/seed/`)

| # | File | Contents |
|---|------|----------|
| 1 | `01_reference_data.sql` (204 lines) | 3 Locations, 10 Job Grades, 10 Departments, 26 Job Titles, 5 Leave Types, 10 Holidays, 8 Pay Elements, Tax Brackets, System Parameters, Lookup Values |
| 2 | `02_employee_data.sql` (173 lines) | 25 Employees across all departments with corresponding Salary Records |

---

## 8. Summary Statistics

| Category | Count |
|----------|------:|
| Forms Modules | 6 |
| PLL Libraries | 2 |
| Menu Modules | 1 |
| PL/SQL Packages | 11 (22 files: spec + body) |
| Database Triggers | 6 (across 2 files) |
| Database Views | 6 |
| Database Tables | 30 |
| Sequences | 25 |
| Seed Data Scripts | 2 |
| **Total Source Files** | **~40** |
| **Total Lines (SQL/PL/SQL)** | **~7 000** |
| **Total Lines (Forms XML)** | **~1 400** |
