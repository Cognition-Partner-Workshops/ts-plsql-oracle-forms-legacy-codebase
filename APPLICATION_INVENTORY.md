# Application Inventory

> **HRMS v4.2** — Oracle Forms 12c (12.2.1.4) + Oracle Database 19c
> Generated from static codebase analysis of ~7,000 lines SQL/PL/SQL and ~1,400 lines Forms XML across 40 source files.

---

## Table of Contents

1. [Layer Summary](#1-layer-summary)
2. [Oracle Forms Modules (UI Layer)](#2-oracle-forms-modules-ui-layer)
3. [PL/SQL Libraries — PLL (Shared Library Layer)](#3-plsql-libraries--pll-shared-library-layer)
4. [Menu Modules](#4-menu-modules)
5. [PL/SQL Packages (Business Logic Layer)](#5-plsql-packages-business-logic-layer)
6. [Database Triggers (Data Integrity Layer)](#6-database-triggers-data-integrity-layer)
7. [Views (Data Access Layer)](#7-views-data-access-layer)
8. [Sequences (Key Generation)](#8-sequences-key-generation)
9. [Schema Tables (Data Definition Layer)](#9-schema-tables-data-definition-layer)
10. [Seed Data Scripts](#10-seed-data-scripts)

---

## 1. Layer Summary

| Layer | Type | Count | Source Path |
|-------|------|------:|-------------|
| UI | Oracle Forms XML exports | 6 | `forms/xml-exports/` |
| UI | PL/SQL Libraries (PLL) | 2 | `forms/libraries/` |
| UI | Menu Modules | 1 | `forms/menus/` |
| Business Logic | PL/SQL Packages | 11 (22 files: .pks + .pkb) | `plsql/packages/` |
| Data Integrity | Database Triggers | 2 files (multiple triggers) | `plsql/triggers/` |
| Data Access | Views | 6 | `schema/views/` |
| Key Generation | Sequences | 25 | `schema/sequences/` |
| Data Definition | Tables | 29 | `schema/tables/` |
| Seed Data | SQL Scripts | 2 | `data/seed/` |
| **Total** | | **40 files** | |

---

## 2. Oracle Forms Modules (UI Layer)

All forms are exported as XML from Oracle Forms Builder 12c (12.2.1.4). Original binaries are `.fmb` files.

### 2.1 HRMS_LOGIN

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_LOGIN.xml` (131 lines) |
| **Purpose** | Login and authentication; entry point to the application |
| **Attached Libraries** | _(none)_ |
| **Menu Module** | _(none — standalone dialog)_ |
| **Data Blocks** | `LOGIN` (non-database control block) |
| **Canvases** | `CVS_LOGIN` (Content) |
| **Windows** | `WIN_LOGIN` (Dialog — non-closeable, non-resizable) |
| **LOVs** | _(none)_ |
| **Alerts** | _(none)_ |

**Triggers:**

| Trigger | Scope | Purpose |
|---------|-------|---------|
| `WHEN-NEW-FORM-INSTANCE` | Form | Sets window title, focuses username field |
| `WHEN-BUTTON-PRESSED` (BTN_LOGIN) | Item | Calls `PKG_SECURITY.authenticate`, stores session in `GLOBAL` variables, opens `HRMS_MENU` via `OPEN_FORM` |
| `KEY-NEXT-ITEM` | Block | Pressing Enter on password field triggers login |

**Package Calls:** `PKG_SECURITY.authenticate`

---

### 2.2 HRMS_MENU

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_MENU.xml` (176 lines) |
| **Purpose** | MDI parent form — main navigation hub after login |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Menu Module** | `MENU_MAIN` (inline definition) |
| **Data Blocks** | `MENU_CONTROL` (non-database control block) |
| **Canvases** | `CVS_MAIN` (Content) |
| **Windows** | `WIN_MAIN` (Document) |
| **LOVs** | _(none)_ |

**Navigation Buttons:**

| Button | Target Form | Permission Check |
|--------|-------------|-----------------|
| `BTN_EMPLOYEES` | `HRMS_EMPLOYEE` | None |
| `BTN_PAYROLL` | `HRMS_PAYROLL` | `PKG_SECURITY.has_permission(PAYROLL, VIEW)` |
| `BTN_LEAVE` | `HRMS_LEAVE` | None |
| `BTN_PERFORMANCE` | `HRMS_PERFORMANCE` | None |
| `BTN_REPORTS` | `HRMS_REPORTS` | `PKG_SECURITY.has_permission(REPORTS, VIEW)` |
| `BTN_LOGOUT` | _(exits)_ | Calls `PKG_SECURITY.logout` |

**Inline Menu Module (`MENU_MAIN`):**

| Menu | Items |
|------|-------|
| File | Logout |
| Modules | Employee Management, Payroll Processing, Leave Management, Performance Reviews, Reports |
| Admin | System Administration, Change Password |
| Help | About HRMS |

**Package Calls:** `PKG_SECURITY.has_permission`, `PKG_SECURITY.logout`

---

### 2.3 HRMS_EMPLOYEE

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_EMPLOYEE.xml` (539 lines) |
| **Purpose** | Employee maintenance — master-detail with personal info, job assignment, compensation history, dependents |
| **Attached Libraries** | `HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB` |
| **Menu Module** | `HRMS_MENU` (external file) |
| **Data Blocks** | 5: `EMPLOYEE`, `SALARY`, `DEPENDENTS` *(implied)*, `EMERGENCY_CONTACTS` *(implied)*, `EMP_HISTORY` *(implied)* |
| **Canvases** | `CVS_MAIN` (Tab — 4 tab pages), `CVS_TOOLBAR` (Horizontal Toolbar) |
| **Tab Pages** | Personal Information, Job & Compensation, Dependents, Employment History |
| **Windows** | `WIN_EMPLOYEE` (Document, 720x550) |
| **LOVs** | 4 defined: `LOV_DEPARTMENTS`, `LOV_JOB_TITLES`, `LOV_MANAGERS`, `LOV_LOCATIONS` |
| **Alerts** | `ALT_CONFIRM_EXIT`, `ALT_CONFIRM_DELETE` |

**EMPLOYEE Block Items (30+ items):**

| Item | Type | Tab Page | Database | Key |
|------|------|----------|----------|-----|
| EMP_ID | Text (hidden) | — | Yes | PK |
| EMP_NUMBER | Text | Personal | Yes (read-only) | — |
| FIRST_NAME | Text | Personal | Yes | — |
| LAST_NAME | Text | Personal | Yes | — |
| DATE_OF_BIRTH | Date | Personal | Yes | — |
| GENDER | List (Poplist) | Personal | Yes | — |
| MARITAL_STATUS | List (Poplist) | Personal | Yes | — |
| EMAIL | Text | Personal | Yes | — |
| PHONE_WORK | Text | Personal | Yes | — |
| PHONE_MOBILE | Text | Personal | Yes | — |
| ADDRESS_LINE1 | Text | Personal | Yes | — |
| ADDRESS_LINE2 | Text | Personal | Yes | — |
| CITY | Text | Personal | Yes | — |
| STATE_PROVINCE | Text | Personal | Yes | — |
| POSTAL_CODE | Text | Personal | Yes | — |
| HIRE_DATE | Date | Job | Yes | — |
| DEPT_ID | Text + LOV | Job | Yes | — |
| DEPT_NAME_DISP | Display | Job | No | — |
| JOB_ID | Text + LOV | Job | Yes | — |
| JOB_TITLE_DISP | Display | Job | No | — |
| MANAGER_EMP_ID | Text + LOV | Job | Yes | — |
| MANAGER_NAME_DISP | Display | Job | No | — |
| LOCATION_CODE | Text + LOV | Job | Yes | — |
| EMPLOYMENT_TYPE | List (Poplist) | Job | Yes | — |
| EMPLOYMENT_STATUS | List (Poplist) | Job | Yes (read-only) | — |
| TERMINATION_DATE | Date | Job | Yes (read-only) | — |
| ACTIVE_FLAG | Text (hidden) | — | Yes | — |
| CREATED_BY | Text (hidden) | — | Yes | — |
| CREATED_DATE | Date (hidden) | — | Yes | — |
| MODIFIED_BY | Text (hidden) | — | Yes | — |
| MODIFIED_DATE | Date (hidden) | — | Yes | — |

**SALARY Block (detail):** Read-only display of `SALARY_RECORDS` joined to `EMPLOYEE` via `EMP_SALARY_REL`.

**Triggers:**

| Trigger | Scope | Purpose |
|---------|-------|---------|
| `WHEN-NEW-FORM-INSTANCE` | Form | Session validation, permission check, LOV init, default query |
| `ON-ERROR` | Form | Suppresses protected-field and no-changes errors, custom lock message |
| `KEY-EXIT` | Form | Unsaved-changes confirmation dialog |
| `PRE-INSERT` | Block (EMPLOYEE) | Sets EMP_ID from sequence, generates EMP_NUMBER, sets audit fields |
| `PRE-UPDATE` | Block (EMPLOYEE) | Sets MODIFIED_BY and MODIFIED_DATE |
| `POST-QUERY` | Block (EMPLOYEE) | Populates display items (dept name, job title, manager name) |
| `WHEN-VALIDATE-ITEM` | Block (EMPLOYEE) | Email validation via `PKG_VALIDATION`, hire date range check, dept/job LOV cascade |

**Package Calls:** `PKG_SECURITY.is_session_valid`, `PKG_SECURITY.has_permission`, `PKG_VALIDATION.validate_email_format`, `PKG_EMPLOYEE.generate_emp_number`

---

### 2.4 HRMS_PAYROLL

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_PAYROLL.xml` (167 lines) |
| **Purpose** | Payroll processing — pay period management, run creation, calculation, approval |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Menu Module** | `HRMS_MENU` (external file) |
| **Data Blocks** | 4: `PAY_PERIOD`, `PAYROLL_RUN`, `PAYROLL_DETAIL` *(implied)*, `PAYSLIP_SUMMARY` *(implied)* |
| **Canvases** | `CVS_MAIN` (Tab — 3 tab pages) |
| **Tab Pages** | Pay Periods, Payroll Runs, Pay Details |
| **Windows** | `WIN_PAYROLL` (Document, 770x560) |
| **LOVs** | 3 *(implied)*: Period, Run Type, Employee |
| **Relations** | `PERIOD_RUN_REL` (PAY_PERIOD → PAYROLL_RUN, auto-query) |

**Action Buttons:**

| Button | Action | Permission |
|--------|--------|-----------|
| `BTN_CREATE_RUN` | `PKG_PAYROLL.create_payroll_run` | Implicit (form-level PAYROLL/VIEW) |
| `BTN_CALCULATE` | `PKG_PAYROLL.calculate_payroll` | Status must be PENDING |
| `BTN_APPROVE` | `PKG_PAYROLL.approve_payroll` | `PKG_SECURITY.has_permission(PAYROLL, APPROVE)` |

**Package Calls:** `PKG_SECURITY.is_session_valid`, `PKG_SECURITY.has_permission`, `PKG_PAYROLL.create_payroll_run`, `PKG_PAYROLL.calculate_payroll`, `PKG_PAYROLL.approve_payroll`

---

### 2.5 HRMS_LEAVE

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_LEAVE.xml` (220 lines) |
| **Purpose** | Leave management — request submission, approval workflow, balance inquiry, team calendar |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Menu Module** | `HRMS_MENU` (external file) |
| **Data Blocks** | 5: `LEAVE_REQUEST`, `NEW_REQUEST`, `LEAVE_BALANCE`, `PENDING_APPROVAL` *(implied)*, `TEAM_CAL` *(implied)* |
| **Canvases** | `CVS_MAIN` (Tab — 4 tab pages) |
| **Tab Pages** | My Requests, Submit Request, Pending Approvals, Team Calendar |
| **Windows** | `WIN_LEAVE` (Document, 720x520) |
| **LOVs** | `LOV_LEAVE_TYPES` |
| **Alerts** | `ALT_CONFIRM_CANCEL` |

**Package Calls:** `PKG_SECURITY.is_session_valid`, `PKG_LEAVE.cancel_leave_request`, `PKG_LEAVE.submit_leave_request`

---

### 2.6 HRMS_PERFORMANCE

| Attribute | Value |
|-----------|-------|
| **File** | `forms/xml-exports/HRMS_PERFORMANCE.xml` (132 lines) |
| **Purpose** | Performance review management — review cycles, self-assessments, manager reviews, goal tracking |
| **Attached Libraries** | `HRMS_COMMON_LIB` |
| **Menu Module** | `HRMS_MENU` (external file) |
| **Data Blocks** | 4: `REVIEW_CYCLE`, `PERFORMANCE_REVIEW`, `PERFORMANCE_GOAL`, `REVIEW_DETAIL` *(implied)* |
| **Canvases** | `CVS_MAIN` (Tab — 3 tab pages) |
| **Tab Pages** | Review Cycles, My Reviews, Goals |
| **Windows** | `WIN_PERFORMANCE` (Document, 770x560) |
| **Relations** | `CYCLE_REVIEW_REL` (REVIEW_CYCLE → PERFORMANCE_REVIEW), `REVIEW_GOAL_REL` (PERFORMANCE_REVIEW → PERFORMANCE_GOAL) |

**Package Calls:** `PKG_SECURITY.is_session_valid`

---

## 3. PL/SQL Libraries — PLL (Shared Library Layer)

### 3.1 HRMS_COMMON_LIB

| Attribute | Value |
|-----------|-------|
| **File** | `forms/libraries/HRMS_COMMON_LIB.pll.sql` (152 lines) |
| **Purpose** | Shared utility code attached to all HRMS forms |
| **Attached By** | All 5 module forms (HRMS_MENU, HRMS_EMPLOYEE, HRMS_PAYROLL, HRMS_LEAVE, HRMS_PERFORMANCE) |
| **Dependencies** | `PKG_COMMON.log_error`, `PKG_SECURITY.is_session_valid` |

**Program Units:**

| Name | Type | Lines | Purpose |
|------|------|------:|---------|
| `handle_error` | Procedure | 16-38 | Global exception handler — logs to DB via `PKG_COMMON.log_error`, displays on status bar, raises `FORM_TRIGGER_FAILURE` |
| `toolbar_save` | Procedure | 44-47 | `COMMIT_FORM` |
| `toolbar_clear` | Procedure | 49-51 | `CLEAR_FORM(ASK_COMMIT)` |
| `toolbar_query` | Procedure | 54-61 | Toggle Enter/Execute query |
| `toolbar_first` | Procedure | 63-66 | `FIRST_RECORD` |
| `toolbar_prev` | Procedure | 68-70 | `PREVIOUS_RECORD` |
| `toolbar_next` | Procedure | 73-76 | `NEXT_RECORD` |
| `toolbar_last` | Procedure | 78-81 | `LAST_RECORD` |
| `toolbar_insert` | Procedure | 83-86 | `CREATE_RECORD` |
| `toolbar_delete` | Procedure | 88-91 | `DELETE_RECORD` |
| `toolbar_exit` | Procedure | 93-96 | `EXIT_FORM(ASK_COMMIT)` |
| `format_date` | Function | 101-104 | Returns `MM/DD/YYYY` formatted string |
| `format_datetime` | Function | 106-109 | Returns `MM/DD/YYYY HH24:MI:SS` formatted string |
| `get_current_user` | Function | 114-117 | Returns `:GLOBAL.current_user` or `USER` |
| `get_session_id` | Function | 119-125 | Returns `:GLOBAL.session_id` as NUMBER |
| `check_session` | Procedure | 127-138 | Validates session exists and is valid via `PKG_SECURITY.is_session_valid` |
| `refresh_lov` | Procedure | 143-151 | Dynamically repopulates a record group by LOV name |

---

### 3.2 HRMS_VALIDATION_LIB

| Attribute | Value |
|-----------|-------|
| **File** | `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` (136 lines) |
| **Purpose** | Client-side validation code shared across forms |
| **Attached By** | `HRMS_EMPLOYEE` |
| **Dependencies** | Direct SQL queries to `JOB_GRADES` |

**Program Units:**

| Name | Type | Lines | Purpose | Known Issues |
|------|------|------:|---------|-------------|
| `validate_email` | Function | 21-41 | Email format validation | **Drift:** Rejects valid subdomain emails (e.g., `user@mail.company.com`) that server-side `PKG_VALIDATION` accepts |
| `validate_phone` | Function | 47-63 | US phone number validation (10-11 digits) | — |
| `validate_ssn` | Function | 69-90 | SSN format validation (9 digits, no all-zero groups) | — |
| `validate_date_not_future` | Function | 96-99 | Ensures date is not in the future | — |
| `validate_salary_range` | Function | 108-135 | Checks salary against grade min/max | Comment says "hard-coded cache" but code queries DB directly — comment/code mismatch |

---

## 4. Menu Modules

### 4.1 HRMS_MENU (Menu Module)

| Attribute | Value |
|-----------|-------|
| **File** | `forms/menus/HRMS_MENU.mmb.sql` (61 lines) |
| **Purpose** | Main menu bar attached to all module forms |
| **Security** | Menu items enabled/disabled at runtime via `PKG_SECURITY.has_permission()` |

**Menu Structure:**

| Menu | Items | Commands |
|------|-------|---------|
| **File** | Save, Save & Exit, Print, Exit | `COMMIT_FORM`, `EXIT_FORM`, `RUN_PRODUCT` |
| **Edit** | Clear Record, Duplicate Record, Delete Record, Insert Record | Standard Forms built-ins |
| **Query** | Enter Query, Execute Query, Cancel Query, Count Matching, Fetch Next Set | Standard Forms built-ins |
| **Navigate** | First/Previous/Next/Last Record, Previous/Next Block | Standard Forms built-ins |
| **Modules** | Employee Management, Payroll Processing, Leave Management, Performance Reviews, Reports & Analytics, System Admin | `OPEN_FORM(...)` |
| **Admin** | Change Password, System Parameters, User Management | Permission-gated |
| **Help** | Contents, About HRMS, Support | `WEB.SHOW_DOCUMENT`, `SHOW_ALERT` |

---

## 5. PL/SQL Packages (Business Logic Layer)

All packages reside in the `HRMS` schema under `plsql/packages/`.

### 5.1 PKG_COMMON

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_COMMON.pks` (spec), `PKG_COMMON.pkb` (body) |
| **Purpose** | Base utility package — logging, date utilities, formatting, configuration parameters |
| **Dependencies** | None (foundation package) |
| **Depended On By** | All other packages |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `log_info` | Procedure | Insert INFO-level log into `AUDIT_LOG` (autonomous transaction) |
| `log_warning` | Procedure | Insert WARNING-level log |
| `log_error` | Procedure | Insert ERROR-level log |
| `get_param` | Function | Retrieve value from `SYSTEM_PARAMETERS` by category + name |
| `set_param` | Procedure | Insert/update `SYSTEM_PARAMETERS` |
| `format_currency` | Function | Format number as currency string |
| `format_phone` | Function | Format phone number string |
| `business_days_between` | Function | Calculate business days between two dates (excludes weekends and `HOLIDAYS` table) |
| `add_business_days` | Function | Add N business days to a date |
| `get_fiscal_year` | Function | Returns fiscal year for a date |
| `get_fiscal_quarter` | Function | Returns fiscal quarter for a date |

---

### 5.2 PKG_AUDIT

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_AUDIT.pks`, `PKG_AUDIT.pkb` |
| **Purpose** | Audit trail logging for all DML operations |
| **Dependencies** | None |
| **Depended On By** | `PKG_SECURITY`, `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `log_change` | Procedure | Records DML operation in `AUDIT_LOG` with old/new values (autonomous transaction) |
| `log_login` | Procedure | Records login attempt |
| `log_logout` | Procedure | Records logout |

---

### 5.3 PKG_VALIDATION

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_VALIDATION.pks`, `PKG_VALIDATION.pkb` |
| **Purpose** | Centralized server-side business rule validation |
| **Dependencies** | `PKG_COMMON` |
| **Depended On By** | `PKG_EMPLOYEE`, Forms (via `WHEN-VALIDATE-ITEM` triggers) |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `validate_email_format` | Function | Email format validation (REGEXP_LIKE — more permissive than client-side) |
| `validate_phone_format` | Function | Phone format validation |
| `validate_ssn_format` | Function | SSN format validation |
| `validate_date_range` | Function | Start/end date range validation |
| `validate_salary` | Function | Salary against grade range |
| `validate_required` | Function | NOT NULL check |

---

### 5.4 PKG_SECURITY

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_SECURITY.pks` (64 lines), `PKG_SECURITY.pkb` (238 lines) |
| **Purpose** | Authentication, session management, RBAC, SSN encryption |
| **Dependencies** | `PKG_COMMON`, `PKG_AUDIT` |
| **Depended On By** | All Forms modules, `PKG_EMPLOYEE` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `authenticate` | Function | Validates credentials, creates session in `USER_SESSIONS`, returns session ID |
| `logout` | Procedure | Invalidates session |
| `is_session_valid` | Function | Checks session status and timeout (30 min) |
| `has_permission` | Function | Simplified role-based check using department and job grade |
| `encrypt_ssn` | Function | AES-256 encryption via `DBMS_CRYPTO` |
| `decrypt_ssn` | Function | AES-256 decryption |
| `hash_password` | Function | **MD5 hash** via `DBMS_CRYPTO.HASH_MD5` |
| `change_password` | Procedure | Updates password hash |

**Constants:**
- `c_encryption_key` — Hard-coded AES key: `HR$ystem_3ncrypt10n_K3y_2024!!`
- `c_session_timeout` — 30 minutes

---

### 5.5 PKG_EMPLOYEE

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_EMPLOYEE.pks` (193 lines), `PKG_EMPLOYEE.pkb` (967 lines) |
| **Purpose** | Employee CRUD, lifecycle management (transfer, promote, terminate, rehire), org chart |
| **Dependencies** | `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION`, **`PKG_PAYROLL`** |
| **Depended On By** | `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE`, `PKG_REPORTING`, `PKG_INTEGRATION` |
| **Circular Dependency** | **PKG_EMPLOYEE ↔ PKG_PAYROLL** |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `create_employee` | Procedure | Full employee creation with salary record |
| `update_employee` | Procedure | Update employee details |
| `transfer_employee` | Procedure | Department/location transfer with `FOR UPDATE NOWAIT` |
| `promote_employee` | Procedure | Job/grade change with new salary record |
| `terminate_employee` | Procedure | Sets termination status, cancels pending leave, ends salary |
| `rehire_employee` | Procedure | Reactivates terminated employee |
| `get_employee` | Function | Returns employee record by ID |
| `get_employee_by_number` | Function | Returns employee record by EMP_NUMBER |
| `get_direct_reports` | Function | Returns cursor of direct reports |
| `get_org_chart` | Function | `CONNECT BY` hierarchical query |
| `get_headcount_by_dept` | Function | Department headcount |
| `get_tenure_years` | Function | Calculates tenure |
| `is_active` | Function | Checks employment status |
| `validate_employee` | Function | Business rule validation |
| `emp_exists` | Function | Existence check |
| `generate_emp_number` | Function | Generates next employee number |
| `search_employees` | Procedure | Dynamic search with multiple criteria |
| `set_session_context` | Procedure | Sets package-level session variables |

**Package Variables (session state):**
- `g_current_user`, `g_current_emp_id`, `g_session_id`, `g_current_dept_id`, `g_current_role`

---

### 5.6 PKG_PAYROLL

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_PAYROLL.pks` (165 lines), `PKG_PAYROLL.pkb` (898 lines) |
| **Purpose** | Salary management, pay period generation, payroll runs, tax calculations |
| **Dependencies** | **`PKG_EMPLOYEE`**, `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |
| **Depended On By** | `PKG_EMPLOYEE`, `PKG_REPORTING`, `PKG_INTEGRATION` |
| **Circular Dependency** | **PKG_PAYROLL ↔ PKG_EMPLOYEE** |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `create_salary_record` | Procedure | End-dates current salary, inserts new record |
| `create_pay_periods` | Procedure | Generates pay periods for a year (MONTHLY/BIWEEKLY) |
| `close_pay_period` | Procedure | Closes pay period |
| `calculate_payroll` | Procedure | Runs payroll for all employees in a run |
| `calculate_employee_pay` | Procedure | Calculates gross, taxes, deductions for one employee |
| `approve_payroll` | Procedure | Approves a payroll run |
| `reverse_payroll` | Procedure | Reverses an approved run |
| `get_current_salary` | Function | Returns current active salary |
| `get_salary_as_of` | Function | Returns salary as of a date |
| `get_current_period` | Function | Returns current open pay period |
| `calculate_federal_tax` | Function | Federal tax via hard-coded 2024 brackets |
| `calculate_state_tax` | Function | State tax (flat rates by state) |
| `calculate_fica` | Function | Social Security (6.2% up to $168,600 wage base) |
| `calculate_medicare` | Function | Medicare (1.45% + 0.9% additional over $200K) |
| `get_ytd_earnings` | Function | Year-to-date earnings sum |
| `get_payslip` | Procedure | Returns payslip cursor |
| `generate_pay_register` | Procedure | Writes pay register to UTL_FILE |
| `create_payroll_run` | Function | *(implied from Forms call)* |

**Constants:**
- `c_ss_wage_base_2024` — $168,600
- `c_ss_rate` — 6.2%
- `c_medicare_rate` — 1.45%
- `c_medicare_additional_rate` — 0.9%
- `c_medicare_additional_threshold` — $200,000

---

### 5.7 PKG_LEAVE

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_LEAVE.pks` (129 lines), `PKG_LEAVE.pkb` (674 lines) |
| **Purpose** | Leave request lifecycle, balance tracking, accrual, carryover |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `submit_leave_request` | Function | Validates and creates leave request, notifies manager |
| `approve_leave_request` | Procedure | Moves balance from PENDING to USED |
| `reject_leave_request` | Procedure | Releases pending balance |
| `cancel_leave_request` | Procedure | Restores balance based on status |
| `get_leave_balance` | Function | Returns available balance |
| `adjust_leave_balance` | Procedure | Manual balance adjustment |
| `initialize_balances` | Procedure | Creates balance records for all leave types |
| `calculate_business_days` | Function | Business days between dates |
| `check_leave_overlap` | Function | Checks for overlapping requests |
| `run_monthly_accrual` | Procedure | Batch: monthly leave accrual for all employees |
| `process_carryover` | Procedure | Batch: year-end carryover to next year |
| `expire_carryover` | Procedure | Batch: removes expired carryover balances |
| `get_pending_requests` | Procedure | Returns cursor of pending requests for approver |
| `get_team_calendar` | Procedure | Returns cursor of approved leave for a team |

---

### 5.8 PKG_PERFORMANCE

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_PERFORMANCE.pks` (98 lines), `PKG_PERFORMANCE.pkb` (321 lines) |
| **Purpose** | Review cycles, self-assessments, manager reviews, goal tracking |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_COMMON`, `PKG_AUDIT`, `PKG_NOTIFICATION` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `create_review_cycle` | Function | Creates review cycle in DRAFT status |
| `open_review_cycle` | Procedure | Transitions DRAFT → OPEN |
| `close_review_cycle` | Procedure | Transitions to CLOSED |
| `create_review` | Function | Creates individual review, notifies employee |
| `submit_self_assessment` | Procedure | Updates status to MANAGER_REVIEW, notifies manager |
| `submit_manager_review` | Procedure | Sets rating and status to COMPLETED |
| `acknowledge_review` | Procedure | Status → ACKNOWLEDGED |
| `add_goal` | Function | Creates performance goal |
| `update_goal_progress` | Procedure | Updates progress percentage |
| `get_team_reviews` | Procedure | Returns cursor of reviews for manager |
| `get_rating_distribution` | Function | Returns rating distribution for cycle |
| `generate_reviews_for_cycle` | Procedure | Batch: creates reviews for all active employees |

---

### 5.9 PKG_NOTIFICATION

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_NOTIFICATION.pks` (43 lines), `PKG_NOTIFICATION.pkb` (178 lines) |
| **Purpose** | Email/SMS/in-app notification queue and delivery |
| **Dependencies** | `PKG_COMMON` |
| **Depended On By** | `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `send_notification` | Procedure | Queues notification (autonomous transaction) |
| `process_queue` | Procedure | Sends pending notifications via `UTL_SMTP` |
| `retry_failed` | Procedure | Resets FAILED notifications to PENDING |
| `cancel_notification` | Procedure | Cancels PENDING notifications |

**Constants:**
- `c_smtp_host`, `c_smtp_port`, `c_from_address`, `c_from_name` — all hard-coded

---

### 5.10 PKG_REPORTING

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_REPORTING.pks` (64 lines), `PKG_REPORTING.pkb` (208 lines) |
| **Purpose** | Headcount, compensation, turnover, compliance reports |
| **Dependencies** | `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_COMMON` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `headcount_report` | Procedure | Headcount by department/location with tenure |
| `compensation_summary` | Procedure | Salary statistics and compa-ratio by dept/grade |
| `turnover_report` | Procedure | Turnover percentage by department |
| `new_hires_report` | Procedure | New hires in date range |
| `leave_utilization_report` | Procedure | Leave utilization by department/type |
| `payroll_summary_report` | Procedure | Payroll totals by department for a period |
| `eeo_compliance_report` | Procedure | EEO category gender breakdown |
| `refresh_reporting_tables` | Procedure | Nightly refresh of denormalized RPT_* tables |

**Custom Types:** `t_report_cursor IS REF CURSOR`

---

### 5.11 PKG_INTEGRATION

| Attribute | Value |
|-----------|-------|
| **Files** | `PKG_INTEGRATION.pks` (51 lines), `PKG_INTEGRATION.pkb` (214 lines) |
| **Purpose** | External system integration — GL journal, benefits feed, time & attendance import |
| **Dependencies** | `PKG_COMMON`, `PKG_PAYROLL`, `PKG_EMPLOYEE` |

**Public API:**

| Name | Type | Purpose |
|------|------|---------|
| `generate_gl_journal` | Procedure | Creates GL journal file from payroll run via `UTL_FILE` (pipe-delimited) |
| `export_benefits_feed` | Procedure | ADP-format fixed-width benefits enrollment file via `UTL_FILE` |
| `import_time_attendance` | Procedure | Reads time data from CSV file (partially implemented — TODO in code) |
| `sync_org_structure` | Procedure | Placeholder for LDAP/AD sync |
| `get_integration_status` | Function | Reads integration status from `SYSTEM_PARAMETERS` |

**Custom Types:** `t_gl_entry` (record), `t_gl_entry_table` (associative array)

**Constants (Oracle Directory Objects):**
- `GL_FEED_OUT`, `BENEFITS_FEED_OUT`, `TIME_ATTENDANCE_IN`

---

## 6. Database Triggers (Data Integrity Layer)

### 6.1 trg_employees.sql

| Trigger | Type | Table | Purpose |
|---------|------|-------|---------|
| `TRG_EMP_BEFORE_INSERT` | BEFORE INSERT (each row) | `EMPLOYEES` | Generates `EMP_ID` from `SEQ_EMPLOYEE`, sets `ACTIVE_FLAG='Y'`, `EMPLOYMENT_STATUS='ACTIVE'`, audit columns |
| `TRG_EMP_BEFORE_UPDATE` | BEFORE UPDATE (each row) | `EMPLOYEES` | Sets `MODIFIED_BY`/`MODIFIED_DATE`, logs to `EMPLOYEE_HISTORY` on status, dept, job, or salary changes |
| `TRG_EMP_INSTEAD_OF_DELETE` | INSTEAD OF DELETE | `VW_ACTIVE_EMPLOYEES` | Performs soft delete (`ACTIVE_FLAG='N'`, `EMPLOYMENT_STATUS='TERMINATED'`) instead of physical delete |
| `TRG_EMP_AFTER_INSERT` | AFTER INSERT (each row) | `EMPLOYEES` | Calls `PKG_AUDIT.log_change` for audit trail |
| `TRG_EMP_AFTER_UPDATE` | AFTER UPDATE (each row) | `EMPLOYEES` | Calls `PKG_AUDIT.log_change` for audit trail |

### 6.2 trg_audit.sql

| Trigger | Type | Table | Purpose |
|---------|------|-------|---------|
| `TRG_SALARY_BEFORE_INSERT` | BEFORE INSERT (each row) | `SALARY_RECORDS` | Generates `SALARY_ID` from `SEQ_SALARY`, sets audit columns, calculates `CHANGE_PCT` |
| `TRG_LEAVE_REQ_BEFORE_INSERT` | BEFORE INSERT (each row) | `LEAVE_REQUESTS` | Generates `REQUEST_ID` from `SEQ_LEAVE_REQUEST`, sets status to `PENDING`, sets audit columns |
| `TRG_REVIEW_BEFORE_INSERT` | BEFORE INSERT (each row) | `PERFORMANCE_REVIEWS` | Generates `REVIEW_ID` from `SEQ_PERFORMANCE_REVIEW`, sets status to `PENDING`, sets audit columns |
| `TRG_AUDIT_LOG_BEFORE_INSERT` | BEFORE INSERT (each row) | `AUDIT_LOG` | Generates `AUDIT_ID` from `SEQ_AUDIT_LOG` |
| `TRG_NOTIFICATION_BEFORE_INSERT` | BEFORE INSERT (each row) | `NOTIFICATION_QUEUE` | Generates `NOTIFICATION_ID` from `SEQ_NOTIFICATION` |

---

## 7. Views (Data Access Layer)

Source: `schema/views/hrms_views.sql` (160 lines)

| View | Source Tables | Purpose |
|------|--------------|---------|
| `VW_ACTIVE_EMPLOYEES` | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS` | Denormalized active employee view with department, job, grade, and location details |
| `VW_ORG_HIERARCHY` | `EMPLOYEES` | Hierarchical org chart using `CONNECT BY PRIOR` with `LEVEL` and `SYS_CONNECT_BY_PATH` |
| `VW_EMPLOYEE_COMPENSATION` | `EMPLOYEES`, `SALARY_RECORDS`, `JOB_GRADES` | Current compensation with grade range and compa-ratio |
| `VW_LEAVE_SUMMARY` | `LEAVE_BALANCES`, `LEAVE_TYPES`, `EMPLOYEES` | Current year leave balances with available balance calculation |
| `VW_PAYROLL_LATEST` | `PAYROLL_DETAILS`, `PAYROLL_RUNS`, `PAY_PERIODS`, `PAY_ELEMENTS`, `EMPLOYEES` | Latest payroll run details per employee |
| `VW_PENDING_APPROVALS` | `LEAVE_REQUESTS`, `EMPLOYEES`, `LEAVE_TYPES` | Pending leave requests awaiting approval |

---

## 8. Sequences (Key Generation)

Source: `schema/sequences/hrms_sequences.sql` (50 lines) — 25 sequences, all `NOCACHE`.

| Sequence | Start | Increment | Used By |
|----------|------:|----------:|---------|
| `SEQ_EMPLOYEE` | 1000 | 1 | `EMPLOYEES.EMP_ID` |
| `SEQ_EMP_NUMBER` | 100000 | 1 | `EMPLOYEES.EMP_NUMBER` generation |
| `SEQ_DEPARTMENT` | 100 | 1 | `DEPARTMENTS.DEPT_ID` |
| `SEQ_LOCATION` | 100 | 1 | `LOCATIONS.LOCATION_CODE` |
| `SEQ_JOB_TITLE` | 100 | 1 | `JOB_TITLES.JOB_ID` |
| `SEQ_JOB_GRADE` | 100 | 1 | `JOB_GRADES.GRADE_ID` |
| `SEQ_SALARY` | 1 | 1 | `SALARY_RECORDS.SALARY_ID` |
| `SEQ_PAY_ELEMENT` | 200 | 1 | `PAY_ELEMENTS.ELEMENT_ID` |
| `SEQ_EMP_PAY_ELEMENT` | 1 | 1 | `EMPLOYEE_PAY_ELEMENTS` |
| `SEQ_PAY_PERIOD` | 1 | 1 | `PAY_PERIODS.PERIOD_ID` |
| `SEQ_PAYROLL_RUN` | 1 | 1 | `PAYROLL_RUNS.RUN_ID` |
| `SEQ_PAYROLL_DETAIL` | 1 | 1 | `PAYROLL_DETAILS.DETAIL_ID` |
| `SEQ_TAX_BRACKET` | 1 | 1 | `TAX_BRACKETS` |
| `SEQ_EMP_TAX` | 1 | 1 | `EMPLOYEE_TAX_INFO` |
| `SEQ_BANK_ACCOUNT` | 1 | 1 | `EMPLOYEE_BANK_ACCOUNTS` |
| `SEQ_LEAVE_TYPE` | 10 | 1 | `LEAVE_TYPES.LEAVE_TYPE_ID` |
| `SEQ_LEAVE_BALANCE` | 1 | 1 | `LEAVE_BALANCES` |
| `SEQ_LEAVE_REQUEST` | 1 | 1 | `LEAVE_REQUESTS.REQUEST_ID` |
| `SEQ_LEAVE_ACCRUAL` | 1 | 1 | `LEAVE_ACCRUAL_LOG` |
| `SEQ_HOLIDAY` | 1 | 1 | `HOLIDAYS` |
| `SEQ_REVIEW_CYCLE` | 1 | 1 | `REVIEW_CYCLES` |
| `SEQ_PERFORMANCE_REVIEW` | 1 | 1 | `PERFORMANCE_REVIEWS` |
| `SEQ_PERFORMANCE_GOAL` | 1 | 1 | `PERFORMANCE_GOALS` |
| `SEQ_AUDIT_LOG` | 1 | 1 | `AUDIT_LOG` |
| `SEQ_NOTIFICATION` | 1 | 1 | `NOTIFICATION_QUEUE` |

> **Note:** All sequences use `NOCACHE`, which is a performance concern under concurrent load. See TECHNICAL_DEBT_REPORT.md.

---

## 9. Schema Tables (Data Definition Layer)

### 9.1 Core Tables (`schema/tables/01_core_tables.sql` — 221 lines)

| Table | Columns | PK | Purpose |
|-------|---------|----|---------|
| `DEPARTMENTS` | 10 | `DEPT_ID` | Department master with hierarchical `PARENT_DEPT_ID` |
| `LOCATIONS` | 12 | `LOCATION_CODE` | Office locations |
| `JOB_GRADES` | 7 | `GRADE_ID` | Salary grade bands (min/max) |
| `JOB_TITLES` | 8 | `JOB_ID` | Job positions with grade and EEO category |
| `EMPLOYEES` | 30+ | `EMP_ID` | Core employee record |
| `EMPLOYEE_HISTORY` | 10 | `HISTORY_ID` | Change tracking for employee field changes |
| `EMPLOYEE_DEPENDENTS` | 10 | `DEPENDENT_ID` | Employee dependents |
| `EMERGENCY_CONTACTS` | 8 | `CONTACT_ID` | Emergency contact information |

### 9.2 Payroll Tables (`schema/tables/02_payroll_tables.sql` — 226 lines)

| Table | Columns | PK | Purpose |
|-------|---------|----|---------|
| `SALARY_RECORDS` | 12 | `SALARY_ID` | Salary history with effective/end dates |
| `PAY_ELEMENTS` | 8 | `ELEMENT_ID` | Pay element definitions (earnings, deductions, benefits, taxes) |
| `EMPLOYEE_PAY_ELEMENTS` | 8 | `EMP_ELEMENT_ID` | Employee-specific pay element assignments |
| `PAY_PERIODS` | 9 | `PERIOD_ID` | Pay period definitions |
| `PAYROLL_RUNS` | 10 | `RUN_ID` | Payroll run execution records |
| `PAYROLL_DETAILS` | 10 | `DETAIL_ID` | Individual payroll line items |
| `TAX_BRACKETS` | 8 | `BRACKET_ID` | Tax bracket definitions |
| `EMPLOYEE_TAX_INFO` | 10 | `TAX_INFO_ID` | Employee tax withholding elections |
| `EMPLOYEE_BANK_ACCOUNTS` | 10 | `ACCOUNT_ID` | Direct deposit information |

### 9.3 Leave Tables (`schema/tables/03_leave_tables.sql` — 125 lines)

| Table | Columns | PK | Purpose |
|-------|---------|----|---------|
| `LEAVE_TYPES` | 14 | `LEAVE_TYPE_ID` | Leave type definitions with accrual rules |
| `LEAVE_BALANCES` | 12 | `(EMP_ID, LEAVE_TYPE_ID, CALENDAR_YEAR)` | Annual leave balance tracking (virtual column `AVAILABLE`) |
| `LEAVE_REQUESTS` | 14 | `REQUEST_ID` | Leave request records with approval workflow |
| `LEAVE_ACCRUAL_LOG` | 7 | `ACCRUAL_ID` | Monthly accrual audit trail |
| `HOLIDAYS` | 6 | `HOLIDAY_ID` | Company holiday calendar |

### 9.4 Performance & System Tables (`schema/tables/04_performance_tables.sql` — 183 lines)

| Table | Columns | PK | Purpose |
|-------|---------|----|---------|
| `REVIEW_CYCLES` | 8 | `CYCLE_ID` | Performance review cycle definitions |
| `PERFORMANCE_REVIEWS` | 12 | `REVIEW_ID` | Individual review records |
| `PERFORMANCE_GOALS` | 10 | `GOAL_ID` | Performance goals with progress tracking |
| `AUDIT_LOG` | 10 | `AUDIT_ID` | System-wide audit trail |
| `SYSTEM_PARAMETERS` | 6 | `(PARAM_CATEGORY, PARAM_NAME)` | Configuration key-value store |
| `NOTIFICATION_QUEUE` | 12 | `NOTIFICATION_ID` | Notification queue |
| `USER_SESSIONS` | 8 | `SESSION_ID` | Active user sessions |
| `LOOKUP_VALUES` | 6 | `(LOOKUP_TYPE, LOOKUP_CODE)` | Generic lookup table |

---

## 10. Seed Data Scripts

| File | Lines | Purpose |
|------|------:|---------|
| `data/seed/01_reference_data.sql` | 204 | Locations (3), Job Grades (10), Departments (10), Job Titles (26), Leave Types (5+), Holidays, Pay Elements, Tax Brackets, Lookup Values |
| `data/seed/02_employee_data.sql` | 173 | 25 sample employees across all departments with salary records |
