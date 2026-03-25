# Dependency Map

> **System**: HRMS (Human Resource Management System) v4.2  
> **Platform**: Oracle Forms 12c / Oracle Database 19c  
> **Schema**: HRMS

---

## 1. Multi-Layer Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                                   │
│                                                                             │
│  HRMS_LOGIN ──► HRMS_MENU ──┬──► HRMS_EMPLOYEE                            │
│                              ├──► HRMS_PAYROLL                              │
│                              ├──► HRMS_LEAVE                                │
│                              ├──► HRMS_PERFORMANCE                          │
│                              └──► HRMS_REPORTS (referenced, not exported)   │
│                                                                             │
│  Shared Libraries: HRMS_COMMON_LIB, HRMS_VALIDATION_LIB                   │
│  Menu Module:      HRMS_MENU.mmb                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                        BUSINESS LOGIC LAYER                                 │
│                                                                             │
│  Infrastructure:  PKG_COMMON ◄── PKG_AUDIT                                 │
│                   PKG_COMMON ◄── PKG_VALIDATION                             │
│                   PKG_COMMON ◄── PKG_NOTIFICATION                           │
│                   PKG_COMMON, PKG_AUDIT ◄── PKG_SECURITY                    │
│                                                                             │
│  Domain:          PKG_EMPLOYEE ◄──────────────────── ⟳ ──► PKG_PAYROLL     │
│                   PKG_EMPLOYEE ◄── PKG_LEAVE                                │
│                   PKG_EMPLOYEE ◄── PKG_PERFORMANCE                          │
│                                                                             │
│  Reporting:       PKG_EMPLOYEE, PKG_PAYROLL ◄── PKG_REPORTING              │
│  Integration:     PKG_PAYROLL, PKG_EMPLOYEE ◄── PKG_INTEGRATION            │
├─────────────────────────────────────────────────────────────────────────────┤
│                        DATA LAYER                                           │
│                                                                             │
│  30 Tables │ 6 Views │ 25 Sequences │ 6 Triggers                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Forms → PLL Library Dependencies

### Form Module to Library Attachment

```
HRMS_LOGIN ─────────────────── (no library attachments)
                                    │
HRMS_MENU ─────────────────── HRMS_COMMON_LIB
                                    │
HRMS_EMPLOYEE ────────────┬── HRMS_COMMON_LIB
                          └── HRMS_VALIDATION_LIB
                                    │
HRMS_PAYROLL ─────────────── HRMS_COMMON_LIB
                                    │
HRMS_LEAVE ───────────────── HRMS_COMMON_LIB
                                    │
HRMS_PERFORMANCE ─────────── HRMS_COMMON_LIB
```

### Library to Package Dependencies

```
HRMS_COMMON_LIB
  ├── PKG_COMMON.log_error        (error handling)
  ├── PKG_COMMON.log_info         (info logging)
  ├── PKG_SECURITY.is_session_valid (session checks)
  └── PKG_SECURITY.has_permission  (RBAC checks)

HRMS_VALIDATION_LIB
  ├── PKG_VALIDATION.validate_email_format
  ├── PKG_VALIDATION.validate_phone_format
  ├── PKG_COMMON.is_valid_email    (delegated)
  └── PKG_COMMON.is_valid_phone    (delegated)
```

---

## 3. Forms → Package Direct Calls

### HRMS_LOGIN

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| BTN_LOGIN.WHEN-BUTTON-PRESSED | `PKG_SECURITY.authenticate(username, password, host)` | User login |
| BTN_LOGIN.WHEN-BUTTON-PRESSED | Direct SQL: `SELECT EMP_ID FROM EMPLOYEES` | Get employee ID after auth |

### HRMS_MENU

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.has_permission(emp_id, module, action)` | Enable/disable menu items |
| BTN_PAYROLL.WHEN-BUTTON-PRESSED | `PKG_SECURITY.has_permission(emp_id, 'PAYROLL', 'VIEW')` | Permission check before opening payroll |
| BTN_REPORTS.WHEN-BUTTON-PRESSED | `PKG_SECURITY.has_permission(emp_id, 'REPORTS', 'VIEW')` | Permission check before opening reports |
| BTN_LOGOUT.WHEN-BUTTON-PRESSED | `PKG_SECURITY.logout(session_id)` | Session termination |

### HRMS_EMPLOYEE

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.is_session_valid(session_id)` | Session validation |
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.has_permission(emp_id, 'EMPLOYEE', 'EDIT')` | Permission check |
| PRE-INSERT | `PKG_EMPLOYEE.generate_emp_number` | Generate employee number |
| WHEN-VALIDATE-ITEM (EMAIL) | `PKG_VALIDATION.validate_email_format(email)` | Email validation |
| POST-QUERY | Direct SQL on DEPARTMENTS, JOB_TITLES, EMPLOYEES | Populate display items |

### HRMS_PAYROLL

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.is_session_valid(session_id)` | Session validation |
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.has_permission(emp_id, 'PAYROLL', 'VIEW')` | Permission check |
| BTN_CREATE_RUN.WHEN-BUTTON-PRESSED | `PKG_PAYROLL.create_payroll_run(period_id, type, user)` | Create payroll run |
| BTN_CALCULATE.WHEN-BUTTON-PRESSED | `PKG_PAYROLL.calculate_payroll(run_id, user)` | Calculate payroll |
| BTN_APPROVE.WHEN-BUTTON-PRESSED | `PKG_SECURITY.has_permission(emp_id, 'PAYROLL', 'APPROVE')` | Approve permission check |
| BTN_APPROVE.WHEN-BUTTON-PRESSED | `PKG_PAYROLL.approve_payroll(run_id, user)` | Approve payroll run |

### HRMS_LEAVE

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.is_session_valid(session_id)` | Session validation |
| BTN_SUBMIT.WHEN-BUTTON-PRESSED | `PKG_LEAVE.submit_leave_request(...)` | Submit leave request |
| BTN_CANCEL_REQUEST.WHEN-BUTTON-PRESSED | `PKG_LEAVE.cancel_leave_request(request_id, reason, user)` | Cancel leave request |
| POST-QUERY | Direct SQL on LEAVE_TYPES, LEAVE_REQUESTS | Populate display items |

### HRMS_PERFORMANCE

| Trigger | Package Call | Purpose |
|---------|-------------|---------|
| WHEN-NEW-FORM-INSTANCE | `PKG_SECURITY.is_session_valid(session_id)` | Session validation |
| POST-QUERY | Direct SQL on EMPLOYEES | Populate employee name |

---

## 4. Package → Package Dependencies

### Dependency Matrix

Rows depend on columns. `X` = direct dependency, `⟳` = circular dependency.

|                   | PKG_COMMON | PKG_AUDIT | PKG_VALIDATION | PKG_NOTIFICATION | PKG_SECURITY | PKG_EMPLOYEE | PKG_PAYROLL | PKG_LEAVE | PKG_PERFORMANCE | PKG_REPORTING | PKG_INTEGRATION |
|-------------------|:----------:|:---------:|:--------------:|:----------------:|:------------:|:------------:|:-----------:|:---------:|:---------------:|:-------------:|:---------------:|
| **PKG_COMMON**        | - | | | | | | | | | | |
| **PKG_AUDIT**         | | - | | | | | | | | | |
| **PKG_VALIDATION**    | X | | - | | | | | | | | |
| **PKG_NOTIFICATION**  | X | | | - | | | | | | | |
| **PKG_SECURITY**      | X | X | | | - | | | | | | |
| **PKG_EMPLOYEE**      | X | X | | X | | - | ⟳ | | | | |
| **PKG_PAYROLL**       | X | X | | X | | ⟳ | - | | | | |
| **PKG_LEAVE**         | X | X | | X | | X | | - | | | |
| **PKG_PERFORMANCE**   | X | X | | X | | X | | | - | | |
| **PKG_REPORTING**     | X | | | | | X | X | | | - | |
| **PKG_INTEGRATION**   | X | | | | | X | X | | | | - |

### Dependency Graph (Textual)

```
PKG_COMMON (base, no dependencies)
  ▲
  ├── PKG_AUDIT (base, no dependencies)
  │     ▲
  │     ├── PKG_SECURITY ◄── PKG_COMMON
  │     │     ▲
  │     │     └── (called by all Forms via HRMS_COMMON_LIB)
  │     │
  │     ├── PKG_EMPLOYEE ◄── PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
  │     │     ▲      │
  │     │     │      └──── PKG_PAYROLL.create_salary_record ────┐
  │     │     │                                                  │
  │     │     ├── PKG_PAYROLL ◄── PKG_COMMON, PKG_AUDIT,  ◄────┘  ⟳ CIRCULAR
  │     │     │     PKG_NOTIFICATION
  │     │     │     ▲
  │     │     │     └── PKG_EMPLOYEE.is_active, PKG_EMPLOYEE.get_employee
  │     │     │
  │     │     ├── PKG_LEAVE ◄── PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
  │     │     │
  │     │     ├── PKG_PERFORMANCE ◄── PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION
  │     │     │
  │     │     ├── PKG_REPORTING ◄── PKG_COMMON, PKG_PAYROLL
  │     │     │
  │     │     └── PKG_INTEGRATION ◄── PKG_COMMON, PKG_PAYROLL
  │     │
  ├── PKG_VALIDATION ◄── PKG_COMMON
  │
  └── PKG_NOTIFICATION ◄── PKG_COMMON
```

---

## 5. Circular Dependencies

### ⟳ PKG_EMPLOYEE ↔ PKG_PAYROLL (CRITICAL)

This is the only circular dependency in the codebase.

**PKG_EMPLOYEE → PKG_PAYROLL**:
- `PKG_EMPLOYEE.create_employee` calls `PKG_PAYROLL.create_salary_record` (line ~300 of PKG_EMPLOYEE.pkb)
- `PKG_EMPLOYEE.promote_employee` calls `PKG_PAYROLL.create_salary_record` (line ~630 of PKG_EMPLOYEE.pkb)
- `PKG_EMPLOYEE.rehire_employee` calls `PKG_PAYROLL.create_salary_record` (line ~780 of PKG_EMPLOYEE.pkb)
- `PKG_EMPLOYEE.terminate_employee` updates SALARY_RECORDS directly (line ~700 of PKG_EMPLOYEE.pkb)

**PKG_PAYROLL → PKG_EMPLOYEE**:
- `PKG_PAYROLL.calculate_employee_pay` calls `PKG_EMPLOYEE.get_employee` to retrieve employee details
- `PKG_PAYROLL.calculate_employee_pay` calls `PKG_EMPLOYEE.is_active` to verify active status
- `PKG_PAYROLL` spec declares dependency on `PKG_EMPLOYEE` (line 7 of PKG_PAYROLL.pks)

**Impact**:
- Compilation order is fragile: must compile specs first (both), then bodies
- Cannot drop/recreate either package independently
- Risk of `ORA-04068` (package state discarded) during hot patching
- Tight coupling makes unit testing impossible without both packages

**Recommended Resolution**:
- Extract salary record management into a new `PKG_SALARY` package
- Or use database-level events/AQ to decouple the create-employee → create-salary-record chain

---

## 6. Package → Table Dependencies

### PKG_COMMON

| Operation | Tables |
|-----------|--------|
| READ | SYSTEM_PARAMETERS |
| WRITE | SYSTEM_PARAMETERS (set_param) |
| WRITE | (implicit: ERROR_LOG via DBMS_OUTPUT / autonomous transaction logging) |

### PKG_AUDIT

| Operation | Tables |
|-----------|--------|
| WRITE | AUDIT_LOG (log_action - autonomous transaction) |
| READ/DELETE | AUDIT_LOG (purge_old_records, get_change_history) |

### PKG_VALIDATION

| Operation | Tables |
|-----------|--------|
| READ | JOB_GRADES (validate_salary_for_grade) |
| READ | HOLIDAYS (is_business_day) |
| READ | EMPLOYEES (validate_required_fields) |

### PKG_NOTIFICATION

| Operation | Tables |
|-----------|--------|
| WRITE | NOTIFICATION_QUEUE (send_notification - autonomous transaction) |
| READ/WRITE | NOTIFICATION_QUEUE (process_queue, retry_failed, cancel_notification) |

### PKG_SECURITY

| Operation | Tables |
|-----------|--------|
| READ | EMPLOYEES (authenticate - lookup by email) |
| WRITE | USER_SESSIONS (authenticate - create session) |
| READ/WRITE | USER_SESSIONS (is_session_valid, logout) |
| READ | JOB_TITLES, JOB_GRADES (has_permission - grade-based RBAC) |

### PKG_EMPLOYEE

| Operation | Tables |
|-----------|--------|
| READ/WRITE | EMPLOYEES (CRUD, lifecycle operations) |
| WRITE | EMPLOYEE_HISTORY (log_history - autonomous transaction) |
| READ | DEPARTMENTS (validate_dept) |
| READ | SALARY_RECORDS (get_employee - current salary subquery) |
| WRITE | SALARY_RECORDS (terminate_employee - end-dates active record) |
| WRITE | EMPLOYEE_PAY_ELEMENTS (terminate_employee - deactivates) |
| WRITE | LEAVE_REQUESTS (terminate_employee - auto-cancels pending) |

### PKG_PAYROLL

| Operation | Tables |
|-----------|--------|
| READ/WRITE | SALARY_RECORDS (create/get/end-date salary records) |
| READ/WRITE | PAY_PERIODS (create/close/get periods) |
| READ/WRITE | PAYROLL_RUNS (create/approve/reverse runs) |
| WRITE | PAYROLL_DETAILS (calculate_employee_pay - insert line items) |
| READ | EMPLOYEE_PAY_ELEMENTS, PAY_ELEMENTS (deduction processing) |
| READ | EMPLOYEE_TAX_INFO (tax calculation) |
| READ | EMPLOYEES (payslip generation, pay register) |
| READ | DEPARTMENTS (pay register - dept names) |
| WRITE | UTL_FILE output (generate_pay_register - flat file) |

### PKG_LEAVE

| Operation | Tables |
|-----------|--------|
| READ/WRITE | LEAVE_REQUESTS (submit/approve/reject/cancel) |
| READ/WRITE | LEAVE_BALANCES (update used/pending/accrued/adjustment) |
| READ | LEAVE_TYPES (validation, accrual rates) |
| READ | EMPLOYEES (validation, team queries) |
| READ | HOLIDAYS (calculate_business_days) |
| WRITE | LEAVE_ACCRUAL_LOG (run_monthly_accrual) |

### PKG_PERFORMANCE

| Operation | Tables |
|-----------|--------|
| READ/WRITE | REVIEW_CYCLES (create/open/close) |
| READ/WRITE | PERFORMANCE_REVIEWS (create/submit/acknowledge) |
| WRITE | PERFORMANCE_GOALS (add_goal, update_goal_progress) |
| READ | EMPLOYEES (generate_reviews_for_cycle, get_team_reviews) |
| READ | JOB_TITLES, DEPARTMENTS (get_team_reviews) |

### PKG_REPORTING

| Operation | Tables |
|-----------|--------|
| READ | EMPLOYEES, DEPARTMENTS, LOCATIONS, JOB_TITLES, JOB_GRADES (headcount, EEO) |
| READ | SALARY_RECORDS (compensation_summary) |
| READ | LEAVE_BALANCES, LEAVE_TYPES (leave_utilization) |
| READ | PAYROLL_DETAILS, PAYROLL_RUNS, PAY_PERIODS (payroll_summary) |

### PKG_INTEGRATION

| Operation | Tables |
|-----------|--------|
| READ | PAYROLL_DETAILS, PAYROLL_RUNS, PAY_PERIODS, EMPLOYEES, DEPARTMENTS, PAY_ELEMENTS (GL journal) |
| READ | EMPLOYEES, EMPLOYEE_DEPENDENTS (benefits feed) |
| WRITE | UTL_FILE output (GL journal, benefits feed - flat files) |
| READ | UTL_FILE input (time attendance import) |

---

## 7. Trigger → Package Dependencies

```
TRG_EMP_BEFORE_INSERT ───► (no package calls; uses SEQ_EMPLOYEE.NEXTVAL directly)
TRG_EMP_BEFORE_UPDATE ───► (no package calls; direct INSERT into EMPLOYEE_HISTORY)
TRG_EMP_INSTEAD_OF_DELETE ► (no package calls; UPDATE EMPLOYEES set ACTIVE_FLAG='N')

TRG_SALARY_AUDIT ─────────► PKG_AUDIT.log_action
TRG_LEAVE_REQUEST_AUDIT ──► PKG_AUDIT.log_action
TRG_DEPARTMENT_AUDIT ─────► PKG_AUDIT.log_action
```

---

## 8. View → Table Dependencies

```
VW_ACTIVE_EMPLOYEES ──────► EMPLOYEES, DEPARTMENTS, JOB_TITLES, JOB_GRADES, LOCATIONS
VW_ORG_HIERARCHY ─────────► EMPLOYEES, JOB_TITLES
VW_EMPLOYEE_COMPENSATION ─► EMPLOYEES, SALARY_RECORDS, JOB_GRADES, DEPARTMENTS
VW_LEAVE_SUMMARY ─────────► LEAVE_BALANCES, LEAVE_TYPES, EMPLOYEES
VW_PAYROLL_LATEST ────────► PAYROLL_RUNS, PAY_PERIODS, PAYROLL_DETAILS, EMPLOYEES
VW_PENDING_APPROVALS ─────► LEAVE_REQUESTS, EMPLOYEES, LEAVE_TYPES
```

---

## 9. End-to-End Call Chains

### Employee Hire Flow

```
HRMS_EMPLOYEE (PRE-INSERT trigger)
  └─► PKG_EMPLOYEE.generate_emp_number
        └─► SELECT MAX(EMP_NUMBER) FROM EMPLOYEES  [⚠ race condition]
  └─► HRMS_EMPLOYEE inserts EMPLOYEES row (Forms DML)
        └─► TRG_EMP_BEFORE_INSERT fires
              └─► SEQ_EMPLOYEE.NEXTVAL (sets EMP_ID)
              └─► Sets ACTIVE_FLAG, EMPLOYMENT_STATUS, audit columns
        └─► TRG_SALARY_AUDIT fires (if salary inserted)
              └─► PKG_AUDIT.log_action
                    └─► INSERT INTO AUDIT_LOG
  └─► PKG_EMPLOYEE.create_employee (if called from package, not Forms)
        └─► PKG_VALIDATION.validate_email_format
              └─► PKG_COMMON.is_valid_email
        └─► PKG_PAYROLL.create_salary_record  [⟳ circular]
              └─► INSERT INTO SALARY_RECORDS
        └─► PKG_NOTIFICATION.send_notification
              └─► INSERT INTO NOTIFICATION_QUEUE
        └─► PKG_AUDIT.log_action
              └─► INSERT INTO AUDIT_LOG
```

### Payroll Processing Flow

```
HRMS_PAYROLL (BTN_CREATE_RUN)
  └─► PKG_PAYROLL.create_payroll_run
        └─► INSERT INTO PAYROLL_RUNS
        └─► PKG_AUDIT.log_action

HRMS_PAYROLL (BTN_CALCULATE)
  └─► PKG_PAYROLL.calculate_payroll
        └─► FOR each active employee:
              └─► PKG_PAYROLL.calculate_employee_pay
                    └─► PKG_EMPLOYEE.get_employee  [⟳ circular]
                    └─► PKG_EMPLOYEE.is_active     [⟳ circular]
                    └─► PKG_PAYROLL.get_current_salary
                    └─► PKG_PAYROLL.get_ytd_earnings
                    └─► PKG_PAYROLL.calculate_federal_tax  [hard-coded 2024 brackets]
                    └─► PKG_PAYROLL.calculate_state_tax    [flat rate approximation]
                    └─► PKG_PAYROLL.calculate_fica
                    └─► PKG_PAYROLL.calculate_medicare
                    └─► INSERT INTO PAYROLL_DETAILS (multiple rows per employee)
              └─► COMMIT every 50 employees  [⚠ partial commit risk]
        └─► PKG_AUDIT.log_action

HRMS_PAYROLL (BTN_APPROVE)
  └─► PKG_SECURITY.has_permission (PAYROLL, APPROVE)
  └─► PKG_PAYROLL.approve_payroll
        └─► UPDATE PAYROLL_RUNS SET STATUS = 'APPROVED'
```

### Leave Request Flow

```
HRMS_LEAVE (BTN_SUBMIT)
  └─► PKG_LEAVE.submit_leave_request
        └─► PKG_EMPLOYEE.is_active
        └─► PKG_LEAVE.calculate_business_days
              └─► SELECT FROM HOLIDAYS (exact date match only - ⚠ bug)
        └─► PKG_LEAVE.check_leave_overlap
              └─► SELECT FROM LEAVE_REQUESTS WHERE STATUS IN ('PENDING','APPROVED')
        └─► PKG_LEAVE.get_leave_balance
              └─► SELECT FROM LEAVE_BALANCES
        └─► INSERT INTO LEAVE_REQUESTS
        └─► UPDATE LEAVE_BALANCES (increment PENDING)
        └─► PKG_NOTIFICATION.send_notification (to approver)
              └─► INSERT INTO NOTIFICATION_QUEUE
        └─► PKG_AUDIT.log_action
              └─► INSERT INTO AUDIT_LOG
```

### Login → Session Flow

```
HRMS_LOGIN (BTN_LOGIN)
  └─► PKG_SECURITY.authenticate(username, password, host)
        └─► SELECT FROM EMPLOYEES WHERE EMAIL = username
        └─► PKG_SECURITY.hash_password  [⚠ MD5]
        └─► INSERT INTO USER_SESSIONS
        └─► PKG_EMPLOYEE.set_session_context
              └─► Sets g_current_user, g_current_emp_id, g_current_dept_id
        └─► PKG_AUDIT.log_action
  └─► SET :GLOBAL.session_id, :GLOBAL.current_user, :GLOBAL.current_emp_id
  └─► OPEN_FORM('HRMS_MENU', ACTIVATE, SESSION)
```

---

## 10. External System Integration Points

```
PKG_INTEGRATION.generate_gl_journal
  └─► READ: PAYROLL_DETAILS, PAYROLL_RUNS, PAY_PERIODS, EMPLOYEES, DEPARTMENTS, PAY_ELEMENTS
  └─► WRITE: UTL_FILE → GL_FEED_OUT directory → pipe-delimited .dat file
  └─► Consumed by: Oracle Financials batch import

PKG_INTEGRATION.export_benefits_feed
  └─► READ: EMPLOYEES, EMPLOYEE_DEPENDENTS
  └─► WRITE: UTL_FILE → BENEFITS_FEED_OUT directory → fixed-width .txt file (ADP format)
  └─► Consumed by: ADP benefits provider

PKG_INTEGRATION.import_time_attendance
  └─► READ: UTL_FILE → TIME_ATTENDANCE_IN directory → CSV file
  └─► NOTE: Parsing/update logic is TODO (stub only)

PKG_NOTIFICATION.process_queue
  └─► READ: NOTIFICATION_QUEUE (PENDING status)
  └─► SEND: UTL_SMTP → smtp.internal.company.com:25  [⚠ hard-coded]
  └─► WRITE: NOTIFICATION_QUEUE (update STATUS to SENT/FAILED)

PKG_PAYROLL.generate_pay_register
  └─► READ: PAYROLL_DETAILS, EMPLOYEES, DEPARTMENTS, PAY_PERIODS
  └─► WRITE: UTL_FILE → PAYROLL_OUTPUT directory → CSV file
```

---

## 11. Compilation Order

Due to the circular dependency between PKG_EMPLOYEE and PKG_PAYROLL, the compilation order must be:

```
1. PKG_COMMON.pks      (no dependencies)
2. PKG_AUDIT.pks       (no dependencies)
3. PKG_VALIDATION.pks  (depends on PKG_COMMON spec)
4. PKG_NOTIFICATION.pks (depends on PKG_COMMON spec)
5. PKG_SECURITY.pks    (depends on PKG_COMMON, PKG_AUDIT specs)
6. PKG_EMPLOYEE.pks    (depends on PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION specs)
7. PKG_PAYROLL.pks     (depends on PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION specs)
   -- Now all specs are compiled; bodies can resolve forward references --
8. PKG_COMMON.pkb
9. PKG_AUDIT.pkb
10. PKG_VALIDATION.pkb
11. PKG_NOTIFICATION.pkb
12. PKG_SECURITY.pkb
13. PKG_EMPLOYEE.pkb    (body calls PKG_PAYROLL.create_salary_record - resolved via spec)
14. PKG_PAYROLL.pkb     (body calls PKG_EMPLOYEE.get_employee, is_active - resolved via spec)
15. PKG_LEAVE.pkb
16. PKG_PERFORMANCE.pkb
17. PKG_REPORTING.pkb
18. PKG_INTEGRATION.pkb
```

**Key Rule**: All `.pks` specifications must be compiled before any `.pkb` body to avoid `ORA-06508` or `ORA-04068` errors from the circular dependency.
