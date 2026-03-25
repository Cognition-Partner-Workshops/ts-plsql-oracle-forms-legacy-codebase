# Application Inventory

> **HRMS Legacy Oracle Forms / PL/SQL Estate**
> Generated from static analysis of the `ts-plsql-oracle-forms-legacy-codebase` repository.

---

## 1. Summary

| Layer | Asset Type | Count |
|---|---|---|
| UI | Oracle Forms XML Exports | 6 |
| UI | PL/SQL Libraries (PLL) | 2 |
| UI | Menu Modules (MMB) | 1 |
| Business Logic | PL/SQL Packages (spec + body) | 11 (22 files) |
| Business Logic | Database Triggers | 6 (across 2 files) |
| Data Access | Database Views | 6 |
| Schema | Tables | 30 |
| Schema | Sequences | 25 |
| Data | Seed Scripts | 2 |
| **Total** | | **~40 files** |

---

## 2. Oracle Forms XML Exports

All forms reside in `forms/xml-exports/` (version-controlled XML representations of `.fmb` binaries).

### 2.1 HRMS_EMPLOYEE.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | Employee maintenance (personal info, job & compensation, dependents, history) |
| **Data Blocks** | `EMPLOYEE`, `SALARY`, `DEPENDENTS`, `HISTORY`, `EMERGENCY_CONTACTS` (5 blocks) |
| **LOVs** | `LOV_DEPARTMENTS`, `LOV_JOBS`, `LOV_MANAGERS`, `LOV_LOCATIONS`, `LOV_GRADES`, `LOV_PAY_FREQ`, `LOV_EMP_TYPE`, `LOV_MARITAL` (8 LOVs) |
| **Tab Pages** | Personal, Job & Compensation, Dependents, History (4 tabs) |
| **Attached Libraries** | `HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB` |
| **Key Triggers** | `WHEN-NEW-FORM-INSTANCE` (session validation, LOV init, permission check), `WHEN-VALIDATE-ITEM` (field-level validation), `PRE-INSERT` (emp number generation via `PKG_EMPLOYEE.generate_emp_number`), `PRE-UPDATE` (audit columns), `POST-QUERY` (display formatting, dependent count), `ON-ERROR` (custom error handling) |
| **Package Calls** | `PKG_SECURITY.validate_session`, `PKG_SECURITY.has_permission`, `PKG_EMPLOYEE.generate_emp_number`, `PKG_EMPLOYEE.get_employee`, `PKG_COMMON.log_error`, `PKG_NOTIFICATION.send_notification` |

### 2.2 HRMS_PAYROLL.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | Payroll processing (pay run initiation, review, approval) |
| **Attached Libraries** | `HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB` |
| **Key Triggers** | `WHEN-NEW-FORM-INSTANCE`, `WHEN-BUTTON-PRESSED` (run payroll, approve), `ON-ERROR` |
| **Package Calls** | `PKG_SECURITY.validate_session`, `PKG_SECURITY.has_permission`, `PKG_PAYROLL.run_payroll`, `PKG_PAYROLL.approve_payroll`, `PKG_PAYROLL.get_payslip`, `PKG_COMMON.log_error` |

### 2.3 HRMS_LEAVE.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | Leave request submission, approval workflow, balance display |
| **Attached Libraries** | `HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB` |
| **Key Triggers** | `WHEN-NEW-FORM-INSTANCE`, `WHEN-VALIDATE-ITEM` (date range validation), `WHEN-BUTTON-PRESSED` (submit, approve, reject), `ON-ERROR` |
| **Package Calls** | `PKG_SECURITY.validate_session`, `PKG_LEAVE.submit_leave_request`, `PKG_LEAVE.approve_leave`, `PKG_LEAVE.reject_leave`, `PKG_LEAVE.get_leave_balance`, `PKG_COMMON.log_error` |

### 2.4 HRMS_PERFORMANCE.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | Performance review workflow (self-assessment, manager review, goal tracking) |
| **Attached Libraries** | `HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB` |
| **Key Triggers** | `WHEN-NEW-FORM-INSTANCE`, `WHEN-BUTTON-PRESSED` (submit self-assessment, submit manager review, acknowledge), `ON-ERROR` |
| **Package Calls** | `PKG_SECURITY.validate_session`, `PKG_PERFORMANCE.submit_self_assessment`, `PKG_PERFORMANCE.submit_manager_review`, `PKG_PERFORMANCE.acknowledge_review`, `PKG_PERFORMANCE.get_team_reviews`, `PKG_COMMON.log_error` |

### 2.5 HRMS_LOGIN.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | User authentication and session initialization |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Key Triggers** | `WHEN-BUTTON-PRESSED` (login action), `KEY-OTHERS` (disable function keys), `WHEN-NEW-FORM-INSTANCE` |
| **Global Variables Set** | `:GLOBAL.session_id`, `:GLOBAL.current_user`, `:GLOBAL.current_emp_id`, `:GLOBAL.user_role` |
| **Package Calls** | `PKG_SECURITY.authenticate`, `PKG_SECURITY.create_session`, `PKG_COMMON.log_info` |

### 2.6 HRMS_MENU.xml

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Purpose** | Main menu navigation hub; role-based module access |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Key Triggers** | `WHEN-NEW-FORM-INSTANCE` (role-based menu enable/disable), `WHEN-BUTTON-PRESSED` (navigate to sub-forms) |
| **Package Calls** | `PKG_SECURITY.has_permission`, `PKG_SECURITY.validate_session` |

---

## 3. PL/SQL Libraries (PLL)

Reside in `forms/libraries/`.

### 3.1 HRMS_COMMON_LIB.pll.sql

| Attribute | Value |
|---|---|
| **Layer** | UI (shared client-side library) |
| **Purpose** | Common utilities for all forms: error handling, toolbar, LOV refresh, navigation, status bar |
| **Key Procedures** | `handle_error` (wraps `FORM_TRIGGER_FAILURE` with logging), `set_toolbar_state`, `refresh_lov` (re-populate Record Groups), `navigate_to_form` (OPEN_FORM wrapper), `show_status_message`, `check_session_valid`, `format_display_date`, `format_currency` |
| **Attached By** | All 6 Forms modules |
| **Package Calls** | `PKG_COMMON.log_error`, `PKG_SECURITY.validate_session` |

### 3.2 HRMS_VALIDATION_LIB.pll.sql

| Attribute | Value |
|---|---|
| **Layer** | UI (shared client-side validation library) |
| **Purpose** | Client-side field validation before server round-trips |
| **Key Procedures** | `validate_email` (domain/format check), `validate_phone`, `validate_ssn_format`, `validate_date_range`, `validate_salary_range`, `validate_required_fields` |
| **Attached By** | All 6 Forms modules (except HRMS_LOGIN uses only HRMS_COMMON_LIB) |
| **Known Issues** | Validation drift: `validate_email` rejects certain subdomains (e.g., `.internal`) that server-side `PKG_VALIDATION.validate_email` accepts |

---

## 4. Menu Modules

### 4.1 HRMS_MENU.mmb.sql

| Attribute | Value |
|---|---|
| **Layer** | UI |
| **Location** | `forms/menus/` |
| **Purpose** | Defines main application menu structure with role-based visibility |
| **Menu Items** | Employee Management, Payroll, Leave Management, Performance, Reports, Administration, Security, Help |
| **Role Gating** | Uses `PKG_SECURITY.has_permission()` to enable/disable menu items per user role |

---

## 5. PL/SQL Packages

All packages reside in `plsql/packages/` with `.pks` (specification) and `.pkb` (body) files.

### 5.1 PKG_COMMON

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Base Utility) |
| **Files** | `PKG_COMMON.pks` (122 lines), `PKG_COMMON.pkb` (182 lines) |
| **Purpose** | Shared utilities: logging, date formatting, config parameter access |
| **Dependencies** | None (base package) |
| **Called By** | All other packages, all forms |
| **Key Procedures/Functions** | `log_error`, `log_info`, `format_date`, `format_currency`, `get_param`, `set_param`, `get_fiscal_year_start`, `business_days_between` |
| **Types** | `t_error_rec` |
| **Tables Accessed** | `AUDIT_LOG` (write), `SYSTEM_PARAMETERS` (read/write) |

### 5.2 PKG_AUDIT

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Cross-Cutting) |
| **Files** | `PKG_AUDIT.pks` (43 lines), `PKG_AUDIT.pkb` (74 lines) |
| **Purpose** | Centralized DML audit trail logging |
| **Dependencies** | None |
| **Called By** | All domain packages, database triggers |
| **Key Procedures** | `log_action` (overloaded: with/without old/new values) |
| **Tables Accessed** | `AUDIT_LOG` (write) |

### 5.3 PKG_VALIDATION

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Validation) |
| **Files** | `PKG_VALIDATION.pks` (78 lines), `PKG_VALIDATION.pkb` (198 lines) |
| **Purpose** | Server-side centralized business rule validation |
| **Dependencies** | `PKG_COMMON` |
| **Called By** | `PKG_EMPLOYEE`, `PKG_LEAVE`, `PKG_PAYROLL` |
| **Key Functions** | `validate_email`, `validate_phone`, `validate_ssn`, `validate_date_range`, `validate_salary_in_range`, `validate_employment_status_transition` |
| **Known Issues** | Server-side `validate_email` accepts subdomains that client-side `HRMS_VALIDATION_LIB.validate_email` rejects (validation drift) |

### 5.4 PKG_NOTIFICATION

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Cross-Cutting) |
| **Files** | `PKG_NOTIFICATION.pks` (44 lines), `PKG_NOTIFICATION.pkb` (156 lines) |
| **Purpose** | Asynchronous notification delivery (email, SMS, in-app) |
| **Dependencies** | `PKG_COMMON` |
| **Called By** | `PKG_EMPLOYEE`, `PKG_LEAVE`, `PKG_PERFORMANCE`, `PKG_PAYROLL` |
| **Key Procedures** | `send_notification`, `process_notification_queue`, `mark_sent`, `mark_failed` |
| **Known Issues** | Hard-coded SMTP server address, no rate limiting, HTML email templates stored as string constants |
| **Tables Accessed** | `NOTIFICATION_QUEUE` (read/write), `EMPLOYEES` (read) |

### 5.5 PKG_SECURITY

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Security) |
| **Files** | `PKG_SECURITY.pks` (82 lines), `PKG_SECURITY.pkb` (238 lines) |
| **Purpose** | Authentication, session management, RBAC, data encryption |
| **Dependencies** | `PKG_COMMON`, `PKG_AUDIT` |
| **Called By** | All forms (authentication/authorization), `HRMS_LOGIN` form |
| **Key Procedures/Functions** | `authenticate`, `create_session`, `validate_session`, `end_session`, `has_permission`, `hash_password`, `encrypt_ssn`, `decrypt_ssn`, `change_password` |
| **Known Issues** | MD5 password hashing, hard-coded `DBMS_CRYPTO` encryption key in source, no account lockout after failed attempts, session timeout uses DB time (not client time), timing attack vulnerability in password comparison |
| **Tables Accessed** | `USER_SESSIONS` (read/write), `EMPLOYEES` (read), `LOOKUP_VALUES` (read for roles), `AUDIT_LOG` (via PKG_AUDIT) |

### 5.6 PKG_EMPLOYEE

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Domain - Core HR) |
| **Files** | `PKG_EMPLOYEE.pks` (133 lines), `PKG_EMPLOYEE.pkb` (967 lines) |
| **Purpose** | Employee CRUD, lifecycle management (transfer, promote, terminate, rehire), org chart |
| **Dependencies** | `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION`, `PKG_PAYROLL` (circular) |
| **Called By** | `HRMS_EMPLOYEE` form, `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE`, `PKG_REPORTING` |
| **Key Procedures/Functions** | `create_employee`, `update_employee`, `get_employee`, `search_employees`, `generate_emp_number`, `transfer_employee`, `promote_employee`, `terminate_employee`, `rehire_employee`, `get_org_chart`, `get_direct_reports` |
| **Types** | `t_emp_rec`, `t_emp_cursor` |
| **Known Issues** | Race condition in `generate_emp_number` (MAX()+1 without SELECT FOR UPDATE), SQL injection in `search_employees` (string concatenation), circular dependency with `PKG_PAYROLL` (calls `PKG_PAYROLL.create_salary_record`) |
| **Tables Accessed** | `EMPLOYEES` (CRUD), `EMPLOYEE_HISTORY` (write), `EMPLOYEE_DEPENDENTS` (read), `EMERGENCY_CONTACTS` (read), `SALARY_RECORDS` (via PKG_PAYROLL) |

### 5.7 PKG_PAYROLL

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Domain - Payroll) |
| **Files** | `PKG_PAYROLL.pks` (113 lines), `PKG_PAYROLL.pkb` (898 lines) |
| **Purpose** | Salary management, pay run execution, tax calculation (federal/state/FICA/Medicare) |
| **Dependencies** | `PKG_EMPLOYEE` (circular), `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |
| **Called By** | `HRMS_PAYROLL` form, `PKG_EMPLOYEE`, `PKG_INTEGRATION`, `PKG_REPORTING` |
| **Key Procedures/Functions** | `create_salary_record`, `run_payroll`, `calculate_employee_pay`, `approve_payroll`, `reverse_payroll`, `calculate_federal_tax`, `calculate_state_tax`, `calculate_fica`, `calculate_medicare`, `get_payslip`, `get_ytd_earnings`, `generate_pay_register` |
| **Types** | `t_payslip_rec`, `t_payslip_cursor` |
| **Known Issues** | Hard-coded 2024 tax brackets (should read from `TAX_BRACKETS` table), row-by-row cursor processing (should use BULK COLLECT + FORALL), overtime calculation does not account for holidays, YTD reset bug for mid-year hires, flat-file pay register via `UTL_FILE` |
| **Tables Accessed** | `SALARY_RECORDS` (CRUD), `PAY_PERIODS` (read), `PAYROLL_RUNS` (CRUD), `PAYROLL_DETAILS` (CRUD), `EMPLOYEE_PAY_ELEMENTS` (read), `PAY_ELEMENTS` (read), `TAX_BRACKETS` (read - but bypassed by hard-coded values), `EMPLOYEE_TAX_INFO` (read), `EMPLOYEES` (read) |

### 5.8 PKG_LEAVE

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Domain - Leave Management) |
| **Files** | `PKG_LEAVE.pks` (74 lines), `PKG_LEAVE.pkb` (674 lines) |
| **Purpose** | Leave request lifecycle, balance tracking, accrual processing, carryover |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |
| **Called By** | `HRMS_LEAVE` form, batch accrual jobs |
| **Key Procedures/Functions** | `submit_leave_request`, `approve_leave`, `reject_leave`, `cancel_leave`, `get_leave_balance`, `check_leave_overlap`, `initialize_balances`, `run_monthly_accrual`, `process_carryover`, `expire_carryover`, `get_pending_requests`, `get_team_calendar` |
| **Types** | `t_leave_cursor` |
| **Known Issues** | `check_leave_overlap` does not account for half-day requests (bug), `expire_carryover` can double-subtract if run twice on the same day, commits inside loops (every 100 employees during accrual) |
| **Tables Accessed** | `LEAVE_REQUESTS` (CRUD), `LEAVE_BALANCES` (CRUD), `LEAVE_TYPES` (read), `LEAVE_ACCRUAL_LOG` (write), `HOLIDAYS` (read), `EMPLOYEES` (read) |

### 5.9 PKG_PERFORMANCE

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Domain - Performance) |
| **Files** | `PKG_PERFORMANCE.pks` (98 lines), `PKG_PERFORMANCE.pkb` (321 lines) |
| **Purpose** | Review cycle management, goal tracking, ratings, review generation |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |
| **Called By** | `HRMS_PERFORMANCE` form, batch calibration job |
| **Key Procedures/Functions** | `create_review_cycle`, `open_review_cycle`, `close_review_cycle`, `create_review`, `submit_self_assessment`, `submit_manager_review`, `acknowledge_review`, `add_goal`, `update_goal_progress`, `get_team_reviews`, `get_rating_distribution`, `generate_reviews_for_cycle` |
| **Types** | `t_review_cursor` |
| **Tables Accessed** | `REVIEW_CYCLES` (CRUD), `PERFORMANCE_REVIEWS` (CRUD), `PERFORMANCE_GOALS` (CRUD), `EMPLOYEES` (read) |

### 5.10 PKG_REPORTING

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Reporting) |
| **Files** | `PKG_REPORTING.pks` (64 lines), `PKG_REPORTING.pkb` (208 lines) |
| **Purpose** | Structured data for headcount, compensation, turnover, compliance reports |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_COMMON` |
| **Called By** | HRMS_REPORTS form (referenced but not in repo), Oracle Reports (.rdf), batch jobs |
| **Key Procedures** | `headcount_report`, `compensation_summary`, `turnover_report`, `new_hires_report`, `leave_utilization_report`, `payroll_summary_report`, `eeo_compliance_report`, `refresh_reporting_tables` |
| **Types** | `t_report_cursor` |
| **Known Issues** | Denormalized reporting tables refreshed nightly (stale during business hours), some reports use hard-coded fiscal year start (Oct 1) |
| **Tables Accessed** | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS`, `SALARY_RECORDS`, `PAYROLL_DETAILS`, `PAYROLL_RUNS`, `PAY_PERIODS`, `LEAVE_BALANCES`, `LEAVE_TYPES` (all read-only) |

### 5.11 PKG_INTEGRATION

| Attribute | Value |
|---|---|
| **Layer** | Business Logic (Integration) |
| **Files** | `PKG_INTEGRATION.pks` (51 lines), `PKG_INTEGRATION.pkb` (214 lines) |
| **Purpose** | External system data exchange: GL journal, benefits feed, time & attendance import |
| **Dependencies** | `PKG_COMMON`, `PKG_PAYROLL`, `PKG_EMPLOYEE` |
| **Called By** | Batch scheduler (nightly GL feed, weekly benefits sync) |
| **Key Procedures/Functions** | `generate_gl_journal`, `export_benefits_feed`, `import_time_attendance`, `sync_org_structure`, `get_integration_status` |
| **Types** | `t_gl_entry`, `t_gl_entry_table` |
| **Known Issues** | Uses `UTL_FILE` flat file exchange instead of APIs, benefits feed is ADP-vendor-specific fixed-width format, no retry logic for failed transfers, FTP credentials stored in cleartext in `SYSTEM_PARAMETERS`, `import_time_attendance` is a stub (parsing not implemented) |
| **Tables Accessed** | `PAYROLL_DETAILS` (read), `PAYROLL_RUNS` (read), `PAY_PERIODS` (read), `PAY_ELEMENTS` (read), `EMPLOYEES` (read), `DEPARTMENTS` (read), `EMPLOYEE_DEPENDENTS` (read), `SYSTEM_PARAMETERS` (read) |

---

## 6. Database Triggers

Reside in `plsql/triggers/`.

### 6.1 trg_employees.sql (3 triggers)

| Trigger | Type | Table | Purpose |
|---|---|---|---|
| `TRG_EMP_BEFORE_INSERT` | BEFORE INSERT, row-level | `EMPLOYEES` | Sets audit columns, defaults `ACTIVE_FLAG`/`EMPLOYMENT_STATUS`, validates hire date (<=180 days future), validates email uniqueness |
| `TRG_EMP_BEFORE_UPDATE` | BEFORE UPDATE, row-level | `EMPLOYEES` | Sets `MODIFIED_BY`/`MODIFIED_DATE`, prevents direct reactivation of terminated employees, logs status/department/job changes to `EMPLOYEE_HISTORY` |
| `TRG_EMP_INSTEAD_OF_DELETE` | BEFORE DELETE, row-level | `EMPLOYEES` | Prevents physical deletion (raises error); implements soft-delete pattern. **Bug**: Forms expects DELETE to succeed but trigger blocks it |

### 6.2 trg_audit.sql (3 triggers)

| Trigger | Type | Table | Purpose |
|---|---|---|---|
| `TRG_SALARY_AUDIT` | AFTER INSERT/UPDATE/DELETE, row-level | `SALARY_RECORDS` | Logs all salary changes to `AUDIT_LOG` via `PKG_AUDIT.log_action` with JSON old/new values |
| `TRG_LEAVE_REQUEST_AUDIT` | AFTER UPDATE OF STATUS, row-level | `LEAVE_REQUESTS` | Logs leave request status changes via `PKG_AUDIT.log_action` |
| `TRG_DEPARTMENT_AUDIT` | AFTER INSERT/UPDATE/DELETE, row-level | `DEPARTMENTS` | Logs all department structure changes via `PKG_AUDIT.log_action` |

---

## 7. Database Views

Reside in `schema/views/hrms_views.sql`.

| View | Layer | Source Tables | Purpose |
|---|---|---|---|
| `VW_ACTIVE_EMPLOYEES` | Data Access | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS`, `SALARY_RECORDS` | Denormalized active employee lookup with current salary |
| `VW_ORG_HIERARCHY` | Data Access | `EMPLOYEES` | Hierarchical org chart using `CONNECT BY`. Performance warning: degrades >500 employees |
| `VW_EMPLOYEE_COMPENSATION` | Data Access | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `SALARY_RECORDS` | Compensation details with compa-ratio calculation |
| `VW_LEAVE_SUMMARY` | Data Access | `LEAVE_BALANCES`, `EMPLOYEES`, `DEPARTMENTS`, `LEAVE_TYPES` | Current-year leave balances with utilization percentages |
| `VW_PAYROLL_LATEST` | Data Access | `PAYROLL_DETAILS`, `EMPLOYEES`, `PAYROLL_RUNS`, `PAY_PERIODS` | Latest approved payroll run details per employee |
| `VW_PENDING_APPROVALS` | Data Access | `LEAVE_REQUESTS`, `EMPLOYEES`, `LEAVE_TYPES`, `PERFORMANCE_REVIEWS`, `REVIEW_CYCLES` | Unified pending approvals across leave and performance modules |

---

## 8. Schema Objects

### 8.1 Tables (30 total)

Reside in `schema/tables/`.

#### Core HR (`01_core_tables.sql`) - 6 tables

| Table | Columns | Key Constraints |
|---|---|---|
| `DEPARTMENTS` | 12 | PK, UK on `DEPT_CODE`, self-referencing FK (`PARENT_DEPT_ID`) |
| `LOCATIONS` | 14 | PK on `LOCATION_CODE` |
| `JOB_GRADES` | 10 | PK, UK on `GRADE_CODE`, CHECK `MAX_SALARY >= MIN_SALARY` |
| `JOB_TITLES` | 11 | PK, UK on `JOB_CODE`, FK to `JOB_GRADES` |
| `EMPLOYEES` | 33 | PK, UK on `EMP_NUMBER`, FKs to `DEPARTMENTS`, `JOB_TITLES`, `LOCATIONS`, self-referencing FK (`MANAGER_EMP_ID`), CHECK constraints on status/type/gender |
| `EMPLOYEE_HISTORY` | 17 | PK, FK to `EMPLOYEES`, CHECK on `CHANGE_TYPE` |
| `EMPLOYEE_DEPENDENTS` | 13 | PK, FK to `EMPLOYEES`, CHECK on `RELATIONSHIP` |
| `EMERGENCY_CONTACTS` | 13 | PK, FK to `EMPLOYEES` |

#### Payroll (`02_payroll_tables.sql`) - 9 tables

| Table | Columns | Key Constraints |
|---|---|---|
| `SALARY_RECORDS` | 17 | PK, FK to `EMPLOYEES`, CHECK on `PAY_FREQUENCY`, `SALARY_BASIS` |
| `PAY_ELEMENTS` | 15 | PK, UK on `ELEMENT_CODE`, CHECK on `ELEMENT_TYPE`, `CALCULATION_TYPE` |
| `EMPLOYEE_PAY_ELEMENTS` | 12 | PK, FKs to `EMPLOYEES`, `PAY_ELEMENTS` |
| `PAY_PERIODS` | 12 | PK, CHECK on `STATUS` |
| `PAYROLL_RUNS` | 17 | PK, FK to `PAY_PERIODS`, CHECK on `RUN_TYPE`, `STATUS` |
| `PAYROLL_DETAILS` | 13 | PK, FKs to `PAYROLL_RUNS`, `EMPLOYEES`, `PAY_ELEMENTS` |
| `TAX_BRACKETS` | 11 | PK, CHECK on `FILING_STATUS` |
| `EMPLOYEE_TAX_INFO` | 14 | PK, FK to `EMPLOYEES`, UK on (`EMP_ID`, `TAX_YEAR`) |
| `EMPLOYEE_BANK_ACCOUNTS` | 16 | PK, FK to `EMPLOYEES`, CHECK on `ACCOUNT_TYPE`, `DEPOSIT_TYPE` |

#### Leave Management (`03_leave_tables.sql`) - 5 tables

| Table | Columns | Key Constraints |
|---|---|---|
| `LEAVE_TYPES` | 17 | PK, UK on `LEAVE_TYPE_CODE`, CHECK on `ACCRUAL_FREQUENCY` |
| `LEAVE_BALANCES` | 14 | PK, FKs to `EMPLOYEES`, `LEAVE_TYPES`, UK on (`EMP_ID`, `LEAVE_TYPE_ID`, `CALENDAR_YEAR`), virtual column `AVAILABLE` |
| `LEAVE_REQUESTS` | 18 | PK, FKs to `EMPLOYEES` (emp + approver), `LEAVE_TYPES`, CHECK on `STATUS`, dates, `HALF_DAY_PERIOD` |
| `LEAVE_ACCRUAL_LOG` | 8 | PK, FKs to `EMPLOYEES`, `LEAVE_TYPES` |
| `HOLIDAYS` | 7 | PK |

#### Performance & System (`04_performance_tables.sql`) - 8 tables

| Table | Columns | Key Constraints |
|---|---|---|
| `REVIEW_CYCLES` | 12 | PK, CHECK on `STATUS` |
| `PERFORMANCE_REVIEWS` | 18 | PK, FKs to `REVIEW_CYCLES`, `EMPLOYEES` (emp + reviewer), CHECK on `STATUS`, rating range 1.0-5.0 |
| `PERFORMANCE_GOALS` | 15 | PK, FKs to `PERFORMANCE_REVIEWS`, `EMPLOYEES`, CHECK on `STATUS`, `GOAL_CATEGORY` |
| `AUDIT_LOG` | 9 | PK, CHECK on `ACTION_TYPE` |
| `SYSTEM_PARAMETERS` | 10 | PK, UK on (`PARAM_GROUP`, `PARAM_CODE`) |
| `NOTIFICATION_QUEUE` | 14 | PK, CHECK on `STATUS`, `NOTIFICATION_TYPE` |
| `USER_SESSIONS` | 8 | PK, FK to `EMPLOYEES` |
| `LOOKUP_VALUES` | 9 | PK, UK on (`LOOKUP_TYPE`, `LOOKUP_CODE`) |

### 8.2 Sequences (25 total)

Reside in `schema/sequences/hrms_sequences.sql`. All use `NOCACHE` (except `SEQ_AUDIT` which uses `CACHE 100`).

| Group | Sequences |
|---|---|
| Core Employee | `SEQ_DEPARTMENT`, `SEQ_LOCATION`, `SEQ_JOB_GRADE`, `SEQ_JOB_TITLE`, `SEQ_EMPLOYEE` (start 10000), `SEQ_EMP_HISTORY`, `SEQ_DEPENDENT`, `SEQ_EMERGENCY_CONTACT`, `SEQ_EMP_NUMBER` (start 1000) |
| Payroll | `SEQ_SALARY`, `SEQ_PAY_ELEMENT`, `SEQ_EMP_PAY_ELEMENT`, `SEQ_PAY_PERIOD`, `SEQ_PAYROLL_RUN`, `SEQ_PAYROLL_DETAIL`, `SEQ_TAX_BRACKET` |
| Leave | `SEQ_LEAVE_TYPE`, `SEQ_LEAVE_BALANCE`, `SEQ_LEAVE_REQUEST`, `SEQ_LEAVE_ACCRUAL`, `SEQ_HOLIDAY` |
| Performance | `SEQ_REVIEW_CYCLE`, `SEQ_PERF_REVIEW`, `SEQ_PERF_GOAL` |
| System | `SEQ_AUDIT` (CACHE 100), `SEQ_NOTIFICATION`, `SEQ_USER_SESSION`, `SEQ_SYSTEM_PARAM`, `SEQ_LOOKUP` |

---

## 9. Seed Data

Reside in `data/seed/`.

### 9.1 01_reference_data.sql (204 lines)
- 3 Locations (HQ New York, Chicago, San Francisco)
- 10 Job Grades (Entry Level through C-Suite)
- 10 Departments (hierarchical with `PARENT_DEPT_ID`)
- 26 Job Titles
- 6 Leave Types (PTO, Sick, Compensatory, FMLA, Jury Duty, Bereavement)
- 10 Holidays (2024 US federal)
- Pay Elements, Tax Brackets, System Parameters, Lookup Values

### 9.2 02_employee_data.sql (173 lines)
- 25 Employees across all departments
- Corresponding Salary Records for each employee
- Covers Executive, HR, Finance, IT, Sales, Marketing, Operations, Legal departments

---

## 10. Layer Classification Summary

```
+------------------------------------------------------------------+
|  LAYER 1: UI (Presentation)                                      |
|  Oracle Forms XML (6) + PLL Libraries (2) + Menu Module (1)      |
+------------------------------------------------------------------+
        |                                                           
        | Forms Triggers call PL/SQL packages via DB connection     
        v                                                           
+------------------------------------------------------------------+
|  LAYER 2: Business Logic                                         |
|  PL/SQL Packages (11) + Database Triggers (6)                    |
|  Cross-cutting: PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION,        |
|                 PKG_VALIDATION, PKG_SECURITY                     |
|  Domain: PKG_EMPLOYEE, PKG_PAYROLL, PKG_LEAVE,                  |
|          PKG_PERFORMANCE                                         |
|  Integration: PKG_REPORTING, PKG_INTEGRATION                    |
+------------------------------------------------------------------+
        |                                                           
        | SQL DML via packages and triggers                         
        v                                                           
+------------------------------------------------------------------+
|  LAYER 3: Data Access                                            |
|  Database Views (6)                                              |
+------------------------------------------------------------------+
        |                                                           
        v                                                           
+------------------------------------------------------------------+
|  LAYER 4: Schema                                                 |
|  Tables (30) + Sequences (25) + Constraints + Indexes            |
+------------------------------------------------------------------+
```
