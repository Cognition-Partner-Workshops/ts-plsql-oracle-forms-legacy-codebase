# Dependency Map

> **HRMS v4.2** — Multi-layer call graph and circular dependency analysis.
> Covers Forms UI → PLL Libraries → PL/SQL Packages → Database Objects.

---

## Table of Contents

1. [Architecture Layers](#1-architecture-layers)
2. [Forms → PLL Library Calls](#2-forms--pll-library-calls)
3. [Forms → Package Calls](#3-forms--package-calls)
4. [PLL → Package Calls](#4-pll--package-calls)
5. [Package → Package Dependencies](#5-package--package-dependencies)
6. [Package → Table DML Operations](#6-package--table-dml-operations)
7. [Trigger → Package Calls](#7-trigger--package-calls)
8. [Trigger → Table Operations](#8-trigger--table-operations)
9. [View → Table Dependencies](#9-view--table-dependencies)
10. [Circular Dependencies](#10-circular-dependencies)
11. [Full Dependency Graph (Text)](#11-full-dependency-graph-text)

---

## 1. Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI LAYER (Forms)                         │
│  HRMS_LOGIN → HRMS_MENU → HRMS_EMPLOYEE / HRMS_PAYROLL /       │
│                            HRMS_LEAVE / HRMS_PERFORMANCE        │
├─────────────────────────────────────────────────────────────────┤
│                   SHARED LIBRARY LAYER (PLL)                    │
│             HRMS_COMMON_LIB    HRMS_VALIDATION_LIB              │
├─────────────────────────────────────────────────────────────────┤
│                  BUSINESS LOGIC LAYER (Packages)                │
│  PKG_COMMON ← PKG_AUDIT ← PKG_VALIDATION ← PKG_SECURITY       │
│  PKG_NOTIFICATION ← PKG_EMPLOYEE ↔ PKG_PAYROLL                 │
│  PKG_LEAVE ← PKG_PERFORMANCE ← PKG_REPORTING ← PKG_INTEGRATION│
├─────────────────────────────────────────────────────────────────┤
│                 DATA INTEGRITY LAYER (Triggers)                 │
│           TRG_EMP_* / TRG_SALARY_* / TRG_LEAVE_REQ_*           │
├─────────────────────────────────────────────────────────────────┤
│                    DATA LAYER (Tables/Views)                    │
│  EMPLOYEES, DEPARTMENTS, SALARY_RECORDS, LEAVE_REQUESTS, ...   │
│  VW_ACTIVE_EMPLOYEES, VW_ORG_HIERARCHY, VW_LEAVE_SUMMARY, ...  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Forms → PLL Library Calls

Each form attaches PLL libraries via `ATTACH_LIBRARY`. The library code becomes available to all triggers within that form.

| Form Module | HRMS_COMMON_LIB | HRMS_VALIDATION_LIB |
|------------|:---------------:|:-------------------:|
| HRMS_LOGIN | — | — |
| HRMS_MENU | **Attached** | — |
| HRMS_EMPLOYEE | **Attached** | **Attached** |
| HRMS_PAYROLL | **Attached** | — |
| HRMS_LEAVE | **Attached** | — |
| HRMS_PERFORMANCE | **Attached** | — |

**Implied PLL procedure usage within Forms:**

| Form | PLL Procedures Used |
|------|-------------------|
| HRMS_EMPLOYEE | `handle_error`, `toolbar_*` (10 procedures), `check_session`, `get_current_user`, `validate_email`, `validate_salary_range` |
| HRMS_PAYROLL | `handle_error`, `toolbar_*`, `check_session` |
| HRMS_LEAVE | `handle_error`, `toolbar_*`, `check_session` |
| HRMS_PERFORMANCE | `handle_error`, `toolbar_*`, `check_session` |
| HRMS_MENU | `check_session`, `get_current_user` |

---

## 3. Forms → Package Calls

Direct PL/SQL package calls from Forms trigger code (inline `<TriggerText>` blocks).

### HRMS_LOGIN

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| BTN_LOGIN `WHEN-BUTTON-PRESSED` | `PKG_SECURITY.authenticate` | Authenticates user, returns session ID |

### HRMS_MENU

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.has_permission` | Check PAYROLL/VIEW, ADMIN/VIEW, REPORTS/VIEW permissions |
| BTN_PAYROLL `WHEN-BUTTON-PRESSED` | `PKG_SECURITY.has_permission` | Gate payroll access |
| BTN_REPORTS `WHEN-BUTTON-PRESSED` | `PKG_SECURITY.has_permission` | Gate reports access |
| BTN_LOGOUT `WHEN-BUTTON-PRESSED` | `PKG_SECURITY.logout` | End session |

### HRMS_EMPLOYEE

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.is_session_valid` | Session check |
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.has_permission` | Permission check (EMPLOYEE/EDIT) |
| `PRE-INSERT` | `PKG_EMPLOYEE.generate_emp_number` | Auto-generate employee number |
| `WHEN-VALIDATE-ITEM` | `PKG_VALIDATION.validate_email_format` | Server-side email validation |

### HRMS_PAYROLL

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.is_session_valid` | Session check |
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.has_permission` | Permission check (PAYROLL/VIEW) |
| BTN_CREATE_RUN `WHEN-BUTTON-PRESSED` | `PKG_PAYROLL.create_payroll_run` | Create payroll run |
| BTN_CALCULATE `WHEN-BUTTON-PRESSED` | `PKG_PAYROLL.calculate_payroll` | Run payroll calculation |
| BTN_APPROVE `WHEN-BUTTON-PRESSED` | `PKG_SECURITY.has_permission` | Check PAYROLL/APPROVE |
| BTN_APPROVE `WHEN-BUTTON-PRESSED` | `PKG_PAYROLL.approve_payroll` | Approve run |

### HRMS_LEAVE

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.is_session_valid` | Session check |
| BTN_CANCEL `WHEN-BUTTON-PRESSED` | `PKG_LEAVE.cancel_leave_request` | Cancel request |
| BTN_SUBMIT `WHEN-BUTTON-PRESSED` | `PKG_LEAVE.submit_leave_request` | Submit new request |

### HRMS_PERFORMANCE

| Trigger | Package.Procedure | Purpose |
|---------|------------------|---------|
| `WHEN-NEW-FORM-INSTANCE` | `PKG_SECURITY.is_session_valid` | Session check |

---

## 4. PLL → Package Calls

Calls from PLL library code into server-side PL/SQL packages.

### HRMS_COMMON_LIB

| PLL Procedure | Package.Procedure | Purpose |
|--------------|------------------|---------|
| `handle_error` | `PKG_COMMON.log_error` | Logs form errors to database |
| `check_session` | `PKG_SECURITY.is_session_valid` | Validates active session |

### HRMS_VALIDATION_LIB

| PLL Function | Direct Table Access | Purpose |
|-------------|-------------------|---------|
| `validate_salary_range` | `SELECT … FROM JOB_GRADES` | Direct SQL query (bypasses packages) |

> **Note:** `HRMS_VALIDATION_LIB` does not call any packages. It issues direct SQL against `JOB_GRADES`, which tightly couples the client-side library to the schema.

---

## 5. Package → Package Dependencies

### Dependency Matrix

Rows depend on columns. **X** = direct call. **C** = circular dependency.

| Package ↓ depends on → | COMMON | AUDIT | VALIDATION | SECURITY | NOTIFICATION | EMPLOYEE | PAYROLL | LEAVE | PERFORMANCE | REPORTING | INTEGRATION |
|------------------------|:------:|:-----:|:----------:|:--------:|:------------:|:--------:|:-------:|:-----:|:-----------:|:---------:|:-----------:|
| **PKG_COMMON** | — | | | | | | | | | | |
| **PKG_AUDIT** | | — | | | | | | | | | |
| **PKG_VALIDATION** | X | | — | | | | | | | | |
| **PKG_SECURITY** | X | X | | — | | | | | | | |
| **PKG_NOTIFICATION** | X | | | | — | | | | | | |
| **PKG_EMPLOYEE** | X | X | | | X | — | **C** | | | | |
| **PKG_PAYROLL** | X | X | | | X | **C** | — | | | | |
| **PKG_LEAVE** | X | X | | | X | X | | — | | | |
| **PKG_PERFORMANCE** | X | X | | | X | X | | | — | | |
| **PKG_REPORTING** | X | | | | | X | X | | | — | |
| **PKG_INTEGRATION** | X | | | | | X | X | | | | — |

### Detailed Call Chains

**PKG_EMPLOYEE → PKG_PAYROLL:**
- `create_employee` → `PKG_PAYROLL.create_salary_record` (line 275 of PKG_EMPLOYEE.pkb)
- `promote_employee` → `PKG_PAYROLL.create_salary_record` (line ~620 of PKG_EMPLOYEE.pkb)

**PKG_PAYROLL → PKG_EMPLOYEE:**
- `calculate_employee_pay` → reads employee data (queries EMPLOYEES table directly, but package spec declares dependency on PKG_EMPLOYEE)
- Package spec line 6: `-- Dependencies: PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION`

**PKG_SECURITY → PKG_EMPLOYEE:**
- `authenticate` → `PKG_EMPLOYEE.set_session_context` (line ~60 of PKG_SECURITY.pkb)

**PKG_LEAVE → PKG_EMPLOYEE:**
- `submit_leave_request` → validates employee status via `PKG_EMPLOYEE.is_active`
- `submit_leave_request` → gets manager via employee data for notification

**PKG_PERFORMANCE → PKG_EMPLOYEE:**
- `generate_reviews_for_cycle` → iterates over active employees

**PKG_REPORTING → PKG_EMPLOYEE, PKG_PAYROLL:**
- Indirect: queries tables managed by those packages

**PKG_INTEGRATION → PKG_EMPLOYEE, PKG_PAYROLL:**
- `generate_gl_journal` → reads payroll data
- `export_benefits_feed` → reads employee + dependent data

### All Packages → PKG_COMMON (logging)

Every package except PKG_AUDIT calls `PKG_COMMON.log_info` or `PKG_COMMON.log_error` for operational logging.

---

## 6. Package → Table DML Operations

### Legend
- **S** = SELECT
- **I** = INSERT
- **U** = UPDATE
- **D** = DELETE (or soft delete via UPDATE of ACTIVE_FLAG)

| Package | Tables Accessed | Operations |
|---------|----------------|------------|
| **PKG_COMMON** | `AUDIT_LOG` | I |
| | `SYSTEM_PARAMETERS` | S, I, U |
| | `HOLIDAYS` | S |
| **PKG_AUDIT** | `AUDIT_LOG` | I |
| **PKG_VALIDATION** | `JOB_GRADES` | S |
| | `EMPLOYEES` | S |
| **PKG_SECURITY** | `EMPLOYEES` | S, U |
| | `USER_SESSIONS` | S, I, U |
| | `AUDIT_LOG` | I (via PKG_AUDIT) |
| **PKG_NOTIFICATION** | `NOTIFICATION_QUEUE` | S, I, U |
| **PKG_EMPLOYEE** | `EMPLOYEES` | S, I, U, D |
| | `EMPLOYEE_HISTORY` | I |
| | `DEPARTMENTS` | S |
| | `JOB_TITLES` | S |
| | `JOB_GRADES` | S |
| | `LOCATIONS` | S |
| | `SALARY_RECORDS` | I (via PKG_PAYROLL) |
| | `LEAVE_REQUESTS` | U (cancel on terminate) |
| | `LEAVE_BALANCES` | U (cancel on terminate) |
| | `AUDIT_LOG` | I (via PKG_AUDIT) |
| **PKG_PAYROLL** | `SALARY_RECORDS` | S, I, U |
| | `PAY_PERIODS` | S, I, U |
| | `PAYROLL_RUNS` | S, I, U |
| | `PAYROLL_DETAILS` | S, I, U |
| | `PAY_ELEMENTS` | S |
| | `EMPLOYEE_PAY_ELEMENTS` | S |
| | `TAX_BRACKETS` | S |
| | `EMPLOYEE_TAX_INFO` | S |
| | `EMPLOYEES` | S |
| | `DEPARTMENTS` | S |
| **PKG_LEAVE** | `LEAVE_REQUESTS` | S, I, U |
| | `LEAVE_BALANCES` | S, I, U |
| | `LEAVE_TYPES` | S |
| | `LEAVE_ACCRUAL_LOG` | I |
| | `EMPLOYEES` | S |
| | `HOLIDAYS` | S |
| **PKG_PERFORMANCE** | `REVIEW_CYCLES` | S, I, U |
| | `PERFORMANCE_REVIEWS` | S, I, U |
| | `PERFORMANCE_GOALS` | S, I, U |
| | `EMPLOYEES` | S |
| **PKG_REPORTING** | `EMPLOYEES` | S |
| | `DEPARTMENTS` | S |
| | `LOCATIONS` | S |
| | `JOB_TITLES` | S |
| | `JOB_GRADES` | S |
| | `SALARY_RECORDS` | S |
| | `PAY_PERIODS` | S |
| | `PAYROLL_RUNS` | S |
| | `PAYROLL_DETAILS` | S |
| | `PAY_ELEMENTS` | S |
| | `LEAVE_BALANCES` | S |
| | `LEAVE_TYPES` | S |
| **PKG_INTEGRATION** | `PAYROLL_DETAILS` | S |
| | `PAYROLL_RUNS` | S |
| | `PAY_PERIODS` | S |
| | `PAY_ELEMENTS` | S |
| | `EMPLOYEES` | S |
| | `EMPLOYEE_DEPENDENTS` | S |
| | `DEPARTMENTS` | S |

---

## 7. Trigger → Package Calls

| Trigger | Fires On | Package Calls |
|---------|----------|---------------|
| `TRG_EMP_AFTER_INSERT` | `EMPLOYEES` INSERT | `PKG_AUDIT.log_change` |
| `TRG_EMP_AFTER_UPDATE` | `EMPLOYEES` UPDATE | `PKG_AUDIT.log_change` |
| `TRG_EMP_BEFORE_UPDATE` | `EMPLOYEES` UPDATE | _(none — direct INSERT into EMPLOYEE_HISTORY)_ |
| `TRG_EMP_INSTEAD_OF_DELETE` | `VW_ACTIVE_EMPLOYEES` DELETE | _(none — direct UPDATE of EMPLOYEES)_ |

---

## 8. Trigger → Table Operations

| Trigger | Source Table | Target Tables | Operations |
|---------|-------------|---------------|------------|
| `TRG_EMP_BEFORE_INSERT` | EMPLOYEES | EMPLOYEES | U (set defaults) |
| `TRG_EMP_BEFORE_UPDATE` | EMPLOYEES | EMPLOYEE_HISTORY | I (change log) |
| `TRG_EMP_AFTER_INSERT` | EMPLOYEES | AUDIT_LOG | I (via PKG_AUDIT) |
| `TRG_EMP_AFTER_UPDATE` | EMPLOYEES | AUDIT_LOG | I (via PKG_AUDIT) |
| `TRG_EMP_INSTEAD_OF_DELETE` | VW_ACTIVE_EMPLOYEES | EMPLOYEES | U (soft delete) |
| `TRG_SALARY_BEFORE_INSERT` | SALARY_RECORDS | SALARY_RECORDS | U (set defaults, calc change %) |
| `TRG_LEAVE_REQ_BEFORE_INSERT` | LEAVE_REQUESTS | LEAVE_REQUESTS | U (set defaults) |
| `TRG_REVIEW_BEFORE_INSERT` | PERFORMANCE_REVIEWS | PERFORMANCE_REVIEWS | U (set defaults) |
| `TRG_AUDIT_LOG_BEFORE_INSERT` | AUDIT_LOG | AUDIT_LOG | U (set PK) |
| `TRG_NOTIFICATION_BEFORE_INSERT` | NOTIFICATION_QUEUE | NOTIFICATION_QUEUE | U (set PK) |

---

## 9. View → Table Dependencies

| View | Base Tables |
|------|------------|
| `VW_ACTIVE_EMPLOYEES` | EMPLOYEES, DEPARTMENTS, JOB_TITLES, JOB_GRADES, LOCATIONS |
| `VW_ORG_HIERARCHY` | EMPLOYEES |
| `VW_EMPLOYEE_COMPENSATION` | EMPLOYEES, SALARY_RECORDS, JOB_GRADES |
| `VW_LEAVE_SUMMARY` | LEAVE_BALANCES, LEAVE_TYPES, EMPLOYEES |
| `VW_PAYROLL_LATEST` | PAYROLL_DETAILS, PAYROLL_RUNS, PAY_PERIODS, PAY_ELEMENTS, EMPLOYEES |
| `VW_PENDING_APPROVALS` | LEAVE_REQUESTS, EMPLOYEES, LEAVE_TYPES |

---

## 10. Circular Dependencies

### 10.1 PKG_EMPLOYEE ↔ PKG_PAYROLL (CONFIRMED)

This is the only circular dependency in the codebase and is explicitly documented in both package specs.

```
PKG_EMPLOYEE                          PKG_PAYROLL
     │                                      │
     │  create_employee (line 275)          │
     ├─────────────────────────────────────►│ create_salary_record
     │                                      │
     │  promote_employee (line ~620)        │
     ├─────────────────────────────────────►│ create_salary_record
     │                                      │
     │               Declared dependency    │
     │◄─────────────────────────────────────┤
     │  (PKG_PAYROLL spec line 6 declares   │
     │   dependency on PKG_EMPLOYEE)        │
```

**Impact:**
- Compilation order matters: must use `ALTER PACKAGE ... COMPILE` after both specs are created
- Forward declarations or package state sharing may cause `ORA-04068` (existing state of packages has been discarded) during recompilation
- Makes unit testing of either package in isolation impossible

**Recommended Resolution:**
- Extract salary record creation into a dedicated `PKG_SALARY` or move it to a shared interface package
- Alternatively, use an event/queue pattern where `PKG_EMPLOYEE` publishes an event and `PKG_PAYROLL` subscribes

### 10.2 Forms DELETE ↔ TRG_EMP_INSTEAD_OF_DELETE (BEHAVIORAL CONFLICT)

Not a code-level circular dependency, but a behavioral one:

```
HRMS_EMPLOYEE Form                     Database
     │                                      │
     │  DELETE_RECORD (toolbar_delete)      │
     ├─────────────────────────────────────►│ TRG_EMP_INSTEAD_OF_DELETE
     │                                      │  (converts to UPDATE, sets
     │                                      │   ACTIVE_FLAG='N')
     │  ◄ Form expects row to be deleted   │
     │    but row still exists              │
     │    → user sees stale record          │
```

**Workaround in use:** Forms code should call `SET_BLOCK_PROPERTY('EMPLOYEE', DEFAULT_WHERE, ...)` to re-filter and then `CLEAR_RECORD` after the delete attempt.

---

## 11. Full Dependency Graph (Text)

### Top-Down Call Flow (Login → Transaction)

```
User
 └─► HRMS_LOGIN (form)
      └─► PKG_SECURITY.authenticate
           ├─► EMPLOYEES (SELECT — verify credentials)
           ├─► USER_SESSIONS (INSERT — create session)
           ├─► PKG_AUDIT.log_login
           │    └─► AUDIT_LOG (INSERT)
           └─► PKG_EMPLOYEE.set_session_context
                └─► (sets package variables)

 └─► HRMS_MENU (form)
      ├─► PKG_SECURITY.has_permission (multiple checks)
      │    └─► EMPLOYEES (SELECT — check dept/grade)
      │
      ├─► OPEN_FORM('HRMS_EMPLOYEE')
      │    ├─► HRMS_COMMON_LIB.check_session
      │    │    └─► PKG_SECURITY.is_session_valid
      │    │         └─► USER_SESSIONS (SELECT)
      │    │
      │    ├─► [PRE-INSERT trigger]
      │    │    └─► PKG_EMPLOYEE.generate_emp_number
      │    │         └─► EMPLOYEES (SELECT MAX + 1)  ← RACE CONDITION
      │    │
      │    └─► [WHEN-VALIDATE-ITEM trigger]
      │         └─► PKG_VALIDATION.validate_email_format
      │
      ├─► OPEN_FORM('HRMS_PAYROLL')
      │    ├─► PKG_PAYROLL.create_payroll_run
      │    │    └─► PAYROLL_RUNS (INSERT)
      │    ├─► PKG_PAYROLL.calculate_payroll
      │    │    ├─► EMPLOYEES (SELECT — active employees)
      │    │    ├─► PKG_PAYROLL.calculate_employee_pay
      │    │    │    ├─► SALARY_RECORDS (SELECT)
      │    │    │    ├─► EMPLOYEE_PAY_ELEMENTS (SELECT)
      │    │    │    ├─► PKG_PAYROLL.calculate_federal_tax
      │    │    │    ├─► PKG_PAYROLL.calculate_state_tax
      │    │    │    ├─► PKG_PAYROLL.calculate_fica
      │    │    │    ├─► PKG_PAYROLL.calculate_medicare
      │    │    │    └─► PAYROLL_DETAILS (INSERT)
      │    │    └─► PAYROLL_RUNS (UPDATE — totals)
      │    └─► PKG_PAYROLL.approve_payroll
      │         ├─► PAYROLL_RUNS (UPDATE — status)
      │         └─► PKG_NOTIFICATION.send_notification
      │              └─► NOTIFICATION_QUEUE (INSERT)
      │
      ├─► OPEN_FORM('HRMS_LEAVE')
      │    ├─► PKG_LEAVE.submit_leave_request
      │    │    ├─► PKG_EMPLOYEE.is_active (SELECT EMPLOYEES)
      │    │    ├─► LEAVE_TYPES (SELECT)
      │    │    ├─► PKG_LEAVE.check_leave_overlap
      │    │    │    └─► LEAVE_REQUESTS (SELECT)
      │    │    ├─► PKG_LEAVE.get_leave_balance
      │    │    │    └─► LEAVE_BALANCES (SELECT)
      │    │    ├─► LEAVE_REQUESTS (INSERT)
      │    │    ├─► LEAVE_BALANCES (UPDATE — pending)
      │    │    └─► PKG_NOTIFICATION.send_notification
      │    │         └─► NOTIFICATION_QUEUE (INSERT)
      │    └─► PKG_LEAVE.approve_leave_request
      │         ├─► LEAVE_REQUESTS (UPDATE — status)
      │         ├─► LEAVE_BALANCES (UPDATE — used)
      │         └─► PKG_NOTIFICATION.send_notification
      │
      └─► OPEN_FORM('HRMS_PERFORMANCE')
           └─► PKG_PERFORMANCE.submit_manager_review
                ├─► PERFORMANCE_REVIEWS (UPDATE)
                └─► PKG_NOTIFICATION.send_notification
```

### Batch Job Call Flows

```
Nightly Batch
 ├─► PKG_LEAVE.run_monthly_accrual
 │    ├─► EMPLOYEES (SELECT — active)
 │    ├─► LEAVE_TYPES (SELECT — accrual types)
 │    ├─► PKG_LEAVE.get_leave_balance
 │    │    └─► LEAVE_BALANCES (SELECT)
 │    ├─► LEAVE_BALANCES (UPDATE)
 │    ├─► LEAVE_ACCRUAL_LOG (INSERT)
 │    └─► COMMIT (every 100 employees)
 │
 ├─► PKG_LEAVE.process_carryover (year-end)
 │    ├─► LEAVE_BALANCES (SELECT)
 │    ├─► LEAVE_TYPES (SELECT)
 │    ├─► PKG_LEAVE.initialize_balances
 │    └─► LEAVE_BALANCES (UPDATE)
 │
 ├─► PKG_LEAVE.expire_carryover
 │    └─► LEAVE_BALANCES (UPDATE)  ← DOUBLE-SUBTRACT BUG
 │
 ├─► PKG_INTEGRATION.generate_gl_journal
 │    ├─► PAYROLL_DETAILS (SELECT)
 │    ├─► PAY_ELEMENTS (SELECT)
 │    ├─► EMPLOYEES (SELECT)
 │    ├─► DEPARTMENTS (SELECT)
 │    └─► UTL_FILE.FOPEN/PUT_LINE/FCLOSE
 │
 ├─► PKG_INTEGRATION.export_benefits_feed
 │    ├─► EMPLOYEES (SELECT)
 │    ├─► EMPLOYEE_DEPENDENTS (SELECT)
 │    └─► UTL_FILE.FOPEN/PUT_LINE/FCLOSE
 │
 ├─► PKG_NOTIFICATION.process_queue
 │    ├─► NOTIFICATION_QUEUE (SELECT, UPDATE)
 │    └─► UTL_SMTP.OPEN_CONNECTION/DATA/QUIT
 │
 └─► PKG_REPORTING.refresh_reporting_tables
      └─► (truncate and repopulate RPT_* tables — placeholder)
```

### External System Interfaces

```
PKG_INTEGRATION
 ├─► Oracle Financials (GL)
 │    Direction: HRMS → Financials (outbound)
 │    Format: Pipe-delimited flat file (.dat)
 │    Transport: UTL_FILE to Oracle Directory GL_FEED_OUT
 │    Trigger: After payroll run approval
 │
 ├─► ADP Benefits Provider
 │    Direction: HRMS → ADP (outbound)
 │    Format: Fixed-width text file
 │    Transport: UTL_FILE to Oracle Directory BENEFITS_FEED_OUT
 │    Trigger: Weekly batch job
 │
 ├─► Time & Attendance System
 │    Direction: External → HRMS (inbound)
 │    Format: CSV
 │    Transport: UTL_FILE from Oracle Directory TIME_ATTENDANCE_IN
 │    Status: PARTIALLY IMPLEMENTED (TODO in code)
 │
 └─► LDAP/Active Directory
      Direction: External → HRMS (sync)
      Status: PLACEHOLDER (not implemented)

PKG_NOTIFICATION
 └─► SMTP Server
      Direction: HRMS → Mail (outbound)
      Transport: UTL_SMTP (hard-coded host/port)
      Config: c_smtp_host, c_smtp_port in package body
```
