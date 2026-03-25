# Dependency Map

> **HRMS Legacy Oracle Forms / PL/SQL Estate**
> Multi-layer call graph with circular dependency identification.

---

## 1. Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 1: Oracle Forms UI                                           │
│  HRMS_LOGIN ─> HRMS_MENU ─> HRMS_EMPLOYEE                         │
│                           ─> HRMS_PAYROLL                          │
│                           ─> HRMS_LEAVE                            │
│                           ─> HRMS_PERFORMANCE                      │
├─────────────────────────────────────────────────────────────────────┤
│  LAYER 1.5: Shared Client Libraries (PLL)                          │
│  HRMS_COMMON_LIB    HRMS_VALIDATION_LIB                            │
├─────────────────────────────────────────────────────────────────────┤
│  LAYER 2: PL/SQL Packages                                          │
│  ┌──────────────────────────────────────┐                          │
│  │ Cross-Cutting:                       │                          │
│  │ PKG_COMMON  PKG_AUDIT  PKG_VALIDATION│                          │
│  │ PKG_NOTIFICATION  PKG_SECURITY       │                          │
│  ├──────────────────────────────────────┤                          │
│  │ Domain:                              │                          │
│  │ PKG_EMPLOYEE <──> PKG_PAYROLL  (!)   │                          │
│  │ PKG_LEAVE  PKG_PERFORMANCE           │                          │
│  ├──────────────────────────────────────┤                          │
│  │ Outbound:                            │                          │
│  │ PKG_REPORTING  PKG_INTEGRATION       │                          │
│  └──────────────────────────────────────┘                          │
├─────────────────────────────────────────────────────────────────────┤
│  LAYER 2.5: Database Triggers                                      │
│  TRG_EMP_BEFORE_INSERT  TRG_EMP_BEFORE_UPDATE                     │
│  TRG_EMP_INSTEAD_OF_DELETE  TRG_SALARY_AUDIT                      │
│  TRG_LEAVE_REQUEST_AUDIT  TRG_DEPARTMENT_AUDIT                    │
├─────────────────────────────────────────────────────────────────────┤
│  LAYER 3: Database Views                                           │
│  VW_ACTIVE_EMPLOYEES  VW_ORG_HIERARCHY                             │
│  VW_EMPLOYEE_COMPENSATION  VW_LEAVE_SUMMARY                       │
│  VW_PAYROLL_LATEST  VW_PENDING_APPROVALS                          │
├─────────────────────────────────────────────────────────────────────┤
│  LAYER 4: Tables (30) + Sequences (25)                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Forms -> PLL Library Dependencies

Every form attaches shared PLL libraries at startup:

```
HRMS_LOGIN ──────────> HRMS_COMMON_LIB
                       
HRMS_MENU ───────────> HRMS_COMMON_LIB
                       
HRMS_EMPLOYEE ───────> HRMS_COMMON_LIB
                    └> HRMS_VALIDATION_LIB
                       
HRMS_PAYROLL ────────> HRMS_COMMON_LIB
                    └> HRMS_VALIDATION_LIB
                       
HRMS_LEAVE ──────────> HRMS_COMMON_LIB
                    └> HRMS_VALIDATION_LIB
                       
HRMS_PERFORMANCE ────> HRMS_COMMON_LIB
                    └> HRMS_VALIDATION_LIB
```

---

## 3. Forms -> PL/SQL Package Dependencies

Direct package calls made from form triggers and PLL libraries:

### 3.1 HRMS_LOGIN

```
HRMS_LOGIN
  ├──> PKG_SECURITY.authenticate
  ├──> PKG_SECURITY.create_session
  └──> PKG_COMMON.log_info
```

### 3.2 HRMS_MENU

```
HRMS_MENU
  ├──> PKG_SECURITY.validate_session
  └──> PKG_SECURITY.has_permission
```

### 3.3 HRMS_EMPLOYEE

```
HRMS_EMPLOYEE
  ├──> PKG_SECURITY.validate_session
  ├──> PKG_SECURITY.has_permission
  ├──> PKG_EMPLOYEE.generate_emp_number
  ├──> PKG_EMPLOYEE.get_employee
  ├──> PKG_EMPLOYEE.create_employee
  ├──> PKG_EMPLOYEE.update_employee
  ├──> PKG_NOTIFICATION.send_notification
  └──> PKG_COMMON.log_error
```

### 3.4 HRMS_PAYROLL

```
HRMS_PAYROLL
  ├──> PKG_SECURITY.validate_session
  ├──> PKG_SECURITY.has_permission
  ├──> PKG_PAYROLL.run_payroll
  ├──> PKG_PAYROLL.approve_payroll
  ├──> PKG_PAYROLL.get_payslip
  └──> PKG_COMMON.log_error
```

### 3.5 HRMS_LEAVE

```
HRMS_LEAVE
  ├──> PKG_SECURITY.validate_session
  ├──> PKG_LEAVE.submit_leave_request
  ├──> PKG_LEAVE.approve_leave
  ├──> PKG_LEAVE.reject_leave
  ├──> PKG_LEAVE.get_leave_balance
  └──> PKG_COMMON.log_error
```

### 3.6 HRMS_PERFORMANCE

```
HRMS_PERFORMANCE
  ├──> PKG_SECURITY.validate_session
  ├──> PKG_PERFORMANCE.submit_self_assessment
  ├──> PKG_PERFORMANCE.submit_manager_review
  ├──> PKG_PERFORMANCE.acknowledge_review
  ├──> PKG_PERFORMANCE.get_team_reviews
  └──> PKG_COMMON.log_error
```

### 3.7 PLL -> Package Dependencies

```
HRMS_COMMON_LIB
  ├──> PKG_COMMON.log_error
  └──> PKG_SECURITY.validate_session

HRMS_VALIDATION_LIB
  └──> (client-side only; no direct package calls - mirrors PKG_VALIDATION logic)
```

---

## 4. PL/SQL Package Inter-Dependencies

### 4.1 Full Dependency Matrix

| Package (depends on ->) | PKG_COMMON | PKG_AUDIT | PKG_VALIDATION | PKG_NOTIFICATION | PKG_SECURITY | PKG_EMPLOYEE | PKG_PAYROLL | PKG_LEAVE | PKG_PERFORMANCE | PKG_REPORTING | PKG_INTEGRATION |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **PKG_COMMON** | - | | | | | | | | | | |
| **PKG_AUDIT** | | - | | | | | | | | | |
| **PKG_VALIDATION** | X | | - | | | | | | | | |
| **PKG_NOTIFICATION** | X | | | - | | | | | | | |
| **PKG_SECURITY** | X | X | | | - | | | | | | |
| **PKG_EMPLOYEE** | X | X | | X | | - | **X (!)** | | | | |
| **PKG_PAYROLL** | X | X | | X | | **X (!)** | - | | | | |
| **PKG_LEAVE** | X | X | | X | | X | | - | | | |
| **PKG_PERFORMANCE** | X | X | | X | | X | | | - | | |
| **PKG_REPORTING** | X | | | | | X | X | | | - | |
| **PKG_INTEGRATION** | X | | | | | X | X | | | | - |

`X` = depends on, `(!)` = circular dependency

### 4.2 Dependency Graph (Packages Only)

```
                    ┌─────────────┐
                    │ PKG_COMMON  │  (no dependencies - base)
                    └──────┬──────┘
                           │
              ┌────────────┼────────────────────────┐
              │            │                        │
              v            v                        v
      ┌──────────┐  ┌─────────────┐         ┌──────────────┐
      │PKG_AUDIT │  │PKG_VALIDATION│         │PKG_NOTIFICATION│
      └────┬─────┘  └─────────────┘         └───────┬──────┘
           │                                         │
           │    ┌────────────────────────────────────┘
           │    │
           v    v
      ┌──────────────┐
      │ PKG_SECURITY │ ──> PKG_COMMON, PKG_AUDIT
      └──────────────┘
      
      ┌──────────────┐         ┌──────────────┐
      │ PKG_EMPLOYEE │ <=====> │ PKG_PAYROLL  │  ** CIRCULAR **
      └──────┬───────┘         └──────┬───────┘
             │                        │
             │ (both depend on PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION)
             │                        │
    ┌────────┼────────┐               │
    │        │        │               │
    v        v        v               v
┌────────┐┌──────────┐┌─────────────┐┌──────────────┐
│PKG_LEAVE││PKG_PERF ││PKG_REPORTING││PKG_INTEGRATION│
└────────┘└──────────┘└─────────────┘└──────────────┘
```

---

## 5. Circular Dependencies

### 5.1 PKG_EMPLOYEE <-> PKG_PAYROLL (CRITICAL)

This is the only circular dependency in the package layer.

**Forward path** (`PKG_EMPLOYEE` -> `PKG_PAYROLL`):
- `PKG_EMPLOYEE.create_employee` calls `PKG_PAYROLL.create_salary_record` at line 275 of `PKG_EMPLOYEE.pkb`
- Purpose: Automatically creates an initial salary record when a new employee is onboarded

**Reverse path** (`PKG_PAYROLL` -> `PKG_EMPLOYEE`):
- `PKG_PAYROLL.run_payroll` queries `EMPLOYEES` table (reads employee status)
- `PKG_PAYROLL.calculate_employee_pay` reads employee data for tax calculations
- Various procedures reference `PKG_EMPLOYEE` types and functions

**Impact**:
- Oracle resolves this at runtime (both package specs compile independently), but it creates tight coupling
- Cannot deploy either package independently
- Makes unit testing difficult; any change to one package can break the other
- Prevents clean module separation for modernization

**Recommended Resolution**:
- Extract salary record creation into a shared service or use database triggers
- Use event-based decoupling (employee created event triggers salary initialization)

---

## 6. Package -> Table Access Map

### 6.1 Write Access (INSERT/UPDATE/DELETE)

| Package | Tables Written |
|---|---|
| `PKG_COMMON` | `AUDIT_LOG`, `SYSTEM_PARAMETERS` |
| `PKG_AUDIT` | `AUDIT_LOG` |
| `PKG_SECURITY` | `USER_SESSIONS` |
| `PKG_EMPLOYEE` | `EMPLOYEES`, `EMPLOYEE_HISTORY`, `EMPLOYEE_DEPENDENTS`, `EMERGENCY_CONTACTS` |
| `PKG_PAYROLL` | `SALARY_RECORDS`, `PAYROLL_RUNS`, `PAYROLL_DETAILS`, `PAY_PERIODS` |
| `PKG_LEAVE` | `LEAVE_REQUESTS`, `LEAVE_BALANCES`, `LEAVE_ACCRUAL_LOG` |
| `PKG_PERFORMANCE` | `REVIEW_CYCLES`, `PERFORMANCE_REVIEWS`, `PERFORMANCE_GOALS` |
| `PKG_NOTIFICATION` | `NOTIFICATION_QUEUE` |
| `PKG_REPORTING` | (RPT_* denormalized tables - referenced but not in repo) |
| `PKG_INTEGRATION` | (writes flat files via UTL_FILE, not tables) |

### 6.2 Read Access (SELECT)

| Package | Tables Read |
|---|---|
| `PKG_COMMON` | `SYSTEM_PARAMETERS` |
| `PKG_SECURITY` | `EMPLOYEES`, `USER_SESSIONS`, `LOOKUP_VALUES` |
| `PKG_EMPLOYEE` | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS`, `SALARY_RECORDS` |
| `PKG_PAYROLL` | `EMPLOYEES`, `SALARY_RECORDS`, `PAY_ELEMENTS`, `EMPLOYEE_PAY_ELEMENTS`, `PAY_PERIODS`, `PAYROLL_RUNS`, `PAYROLL_DETAILS`, `EMPLOYEE_TAX_INFO`, `TAX_BRACKETS`, `DEPARTMENTS` |
| `PKG_LEAVE` | `EMPLOYEES`, `LEAVE_TYPES`, `LEAVE_BALANCES`, `LEAVE_REQUESTS`, `HOLIDAYS` |
| `PKG_PERFORMANCE` | `EMPLOYEES`, `REVIEW_CYCLES`, `PERFORMANCE_REVIEWS`, `JOB_TITLES`, `DEPARTMENTS` |
| `PKG_REPORTING` | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS`, `SALARY_RECORDS`, `PAYROLL_DETAILS`, `PAYROLL_RUNS`, `PAY_PERIODS`, `LEAVE_BALANCES`, `LEAVE_TYPES` |
| `PKG_INTEGRATION` | `PAYROLL_DETAILS`, `PAYROLL_RUNS`, `PAY_PERIODS`, `PAY_ELEMENTS`, `EMPLOYEES`, `DEPARTMENTS`, `EMPLOYEE_DEPENDENTS`, `SYSTEM_PARAMETERS` |

---

## 7. Trigger -> Package/Table Dependencies

| Trigger | Fires On | Reads | Writes | Calls |
|---|---|---|---|---|
| `TRG_EMP_BEFORE_INSERT` | `EMPLOYEES` INSERT | `EMPLOYEES` (email check) | `:NEW` fields | - |
| `TRG_EMP_BEFORE_UPDATE` | `EMPLOYEES` UPDATE | `:OLD`/`:NEW` fields | `EMPLOYEE_HISTORY` | - |
| `TRG_EMP_INSTEAD_OF_DELETE` | `EMPLOYEES` DELETE | - | - | `RAISE_APPLICATION_ERROR` |
| `TRG_SALARY_AUDIT` | `SALARY_RECORDS` I/U/D | `:OLD`/`:NEW` fields | - | `PKG_AUDIT.log_action` |
| `TRG_LEAVE_REQUEST_AUDIT` | `LEAVE_REQUESTS` UPDATE(STATUS) | `:OLD`/`:NEW` fields | - | `PKG_AUDIT.log_action` |
| `TRG_DEPARTMENT_AUDIT` | `DEPARTMENTS` I/U/D | `:OLD`/`:NEW` fields | - | `PKG_AUDIT.log_action` |

---

## 8. View -> Table Dependencies

| View | Source Tables |
|---|---|
| `VW_ACTIVE_EMPLOYEES` | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `LOCATIONS`, `SALARY_RECORDS` |
| `VW_ORG_HIERARCHY` | `EMPLOYEES` (hierarchical `CONNECT BY`) |
| `VW_EMPLOYEE_COMPENSATION` | `EMPLOYEES`, `DEPARTMENTS`, `JOB_TITLES`, `JOB_GRADES`, `SALARY_RECORDS` |
| `VW_LEAVE_SUMMARY` | `LEAVE_BALANCES`, `EMPLOYEES`, `DEPARTMENTS`, `LEAVE_TYPES` |
| `VW_PAYROLL_LATEST` | `PAYROLL_DETAILS`, `EMPLOYEES`, `PAYROLL_RUNS`, `PAY_PERIODS` |
| `VW_PENDING_APPROVALS` | `LEAVE_REQUESTS`, `EMPLOYEES`, `LEAVE_TYPES`, `PERFORMANCE_REVIEWS`, `REVIEW_CYCLES` |

---

## 9. End-to-End Call Chains

### 9.1 Employee Creation Flow

```
HRMS_LOGIN (Form)
  └──> PKG_SECURITY.authenticate ──> EMPLOYEES, USER_SESSIONS
  └──> PKG_SECURITY.create_session ──> USER_SESSIONS

HRMS_MENU (Form)
  └──> PKG_SECURITY.has_permission ──> LOOKUP_VALUES

HRMS_EMPLOYEE (Form)
  ├──> HRMS_VALIDATION_LIB.validate_email (client-side)
  ├──> HRMS_VALIDATION_LIB.validate_phone (client-side)
  ├──> PKG_EMPLOYEE.generate_emp_number
  │       └──> SELECT MAX() FROM EMPLOYEES  (** race condition **)
  │       └──> SEQ_EMPLOYEE.NEXTVAL (fallback)
  ├──> PKG_EMPLOYEE.create_employee
  │       ├──> INSERT INTO EMPLOYEES
  │       │       └──> TRG_EMP_BEFORE_INSERT fires
  │       │             └──> SELECT FROM EMPLOYEES (email uniqueness)
  │       ├──> INSERT INTO EMPLOYEE_HISTORY
  │       ├──> PKG_PAYROLL.create_salary_record  (** circular dep **)
  │       │       └──> INSERT INTO SALARY_RECORDS
  │       │             └──> TRG_SALARY_AUDIT fires
  │       │                   └──> PKG_AUDIT.log_action
  │       │                         └──> INSERT INTO AUDIT_LOG
  │       ├──> PKG_AUDIT.log_action ──> AUDIT_LOG
  │       └──> PKG_NOTIFICATION.send_notification
  │               └──> INSERT INTO NOTIFICATION_QUEUE
  └──> PKG_COMMON.log_error (on error) ──> AUDIT_LOG
```

### 9.2 Payroll Processing Flow

```
HRMS_PAYROLL (Form)
  ├──> PKG_PAYROLL.run_payroll
  │       ├──> INSERT INTO PAYROLL_RUNS
  │       ├──> FOR each active EMPLOYEE:
  │       │       └──> PKG_PAYROLL.calculate_employee_pay
  │       │             ├──> SELECT FROM SALARY_RECORDS
  │       │             ├──> SELECT FROM EMPLOYEE_TAX_INFO
  │       │             ├──> calculate_federal_tax (hard-coded brackets)
  │       │             ├──> calculate_state_tax
  │       │             ├──> calculate_fica
  │       │             ├──> calculate_medicare
  │       │             ├──> SELECT FROM EMPLOYEE_PAY_ELEMENTS + PAY_ELEMENTS
  │       │             └──> INSERT INTO PAYROLL_DETAILS (multiple rows)
  │       ├──> UPDATE PAYROLL_RUNS (totals)
  │       └──> PKG_COMMON.log_error (on per-employee error)
  ├──> PKG_PAYROLL.approve_payroll
  │       └──> UPDATE PAYROLL_RUNS (status + approver)
  └──> PKG_INTEGRATION.generate_gl_journal
          ├──> SELECT FROM PAYROLL_DETAILS, PAY_ELEMENTS, DEPARTMENTS
          └──> UTL_FILE.FOPEN/PUT_LINE/FCLOSE (flat file)
```

### 9.3 Leave Request Flow

```
HRMS_LEAVE (Form)
  ├──> PKG_LEAVE.submit_leave_request
  │       ├──> PKG_LEAVE.check_leave_overlap  (** half-day bug **)
  │       │       └──> SELECT FROM LEAVE_REQUESTS
  │       ├──> PKG_LEAVE.get_leave_balance
  │       │       └──> SELECT FROM LEAVE_BALANCES
  │       ├──> INSERT INTO LEAVE_REQUESTS
  │       ├──> UPDATE LEAVE_BALANCES (pending)
  │       ├──> PKG_AUDIT.log_action ──> AUDIT_LOG
  │       └──> PKG_NOTIFICATION.send_notification ──> NOTIFICATION_QUEUE
  ├──> PKG_LEAVE.approve_leave
  │       ├──> UPDATE LEAVE_REQUESTS (status)
  │       │       └──> TRG_LEAVE_REQUEST_AUDIT fires
  │       │             └──> PKG_AUDIT.log_action ──> AUDIT_LOG
  │       ├──> UPDATE LEAVE_BALANCES (used, pending)
  │       └──> PKG_NOTIFICATION.send_notification
  └──> Batch: PKG_LEAVE.run_monthly_accrual
          ├──> FOR each EMPLOYEE x LEAVE_TYPE:
          │       ├──> UPDATE LEAVE_BALANCES
          │       └──> INSERT INTO LEAVE_ACCRUAL_LOG
          └──> COMMIT (every 100 employees)
```

### 9.4 Performance Review Flow

```
HRMS_PERFORMANCE (Form)
  ├──> PKG_PERFORMANCE.generate_reviews_for_cycle
  │       └──> FOR each active EMPLOYEE with manager:
  │             ├──> PKG_PERFORMANCE.create_review
  │             │       ├──> INSERT INTO PERFORMANCE_REVIEWS
  │             │       └──> PKG_NOTIFICATION.send_notification
  │             └──> COMMIT
  ├──> PKG_PERFORMANCE.submit_self_assessment
  │       ├──> UPDATE PERFORMANCE_REVIEWS
  │       └──> PKG_NOTIFICATION.send_notification (to manager)
  ├──> PKG_PERFORMANCE.submit_manager_review
  │       ├──> UPDATE PERFORMANCE_REVIEWS (rating, assessment)
  │       └──> PKG_NOTIFICATION.send_notification (to employee)
  └──> PKG_PERFORMANCE.acknowledge_review
          └──> UPDATE PERFORMANCE_REVIEWS (ack date, comments)
```

---

## 10. External Integration Dependencies

```
PKG_INTEGRATION
  ├──> Oracle Directory Objects:
  │       ├── GL_FEED_OUT      (write: GL journal files)
  │       ├── BENEFITS_FEED_OUT (write: ADP benefits files)
  │       └── TIME_ATTENDANCE_IN (read: time import files)
  │
  ├──> UTL_FILE (Oracle built-in for file I/O)
  │
  ├──> SYSTEM_PARAMETERS table (FTP credentials in cleartext)
  │
  └──> External Systems (via flat files):
          ├── Oracle Financials (GL journal, pipe-delimited .dat)
          ├── ADP Benefits (fixed-width .txt)
          └── Time & Attendance (CSV import - stub only)

PKG_NOTIFICATION
  └──> UTL_SMTP / UTL_MAIL (hard-coded SMTP server)

PKG_SECURITY
  └──> DBMS_CRYPTO (encryption - hard-coded key)

PKG_PAYROLL
  └──> UTL_FILE (pay register CSV output)
```

---

## 11. Sequence Usage Map

| Sequence | Used By | Table |
|---|---|---|
| `SEQ_DEPARTMENT` | DDL/seed scripts | `DEPARTMENTS` |
| `SEQ_LOCATION` | DDL/seed scripts | `LOCATIONS` |
| `SEQ_JOB_GRADE` | DDL/seed scripts | `JOB_GRADES` |
| `SEQ_JOB_TITLE` | DDL/seed scripts | `JOB_TITLES` |
| `SEQ_EMPLOYEE` | `PKG_EMPLOYEE`, `TRG_EMP_BEFORE_INSERT` | `EMPLOYEES` |
| `SEQ_EMP_NUMBER` | `PKG_EMPLOYEE.generate_emp_number` (fallback only) | `EMPLOYEES.EMP_NUMBER` |
| `SEQ_EMP_HISTORY` | `TRG_EMP_BEFORE_UPDATE`, `PKG_EMPLOYEE` | `EMPLOYEE_HISTORY` |
| `SEQ_DEPENDENT` | `PKG_EMPLOYEE` | `EMPLOYEE_DEPENDENTS` |
| `SEQ_EMERGENCY_CONTACT` | `PKG_EMPLOYEE` | `EMERGENCY_CONTACTS` |
| `SEQ_SALARY` | `PKG_PAYROLL` | `SALARY_RECORDS` |
| `SEQ_PAY_ELEMENT` | seed scripts | `PAY_ELEMENTS` |
| `SEQ_EMP_PAY_ELEMENT` | `PKG_PAYROLL` | `EMPLOYEE_PAY_ELEMENTS` |
| `SEQ_PAY_PERIOD` | `PKG_PAYROLL` | `PAY_PERIODS` |
| `SEQ_PAYROLL_RUN` | `PKG_PAYROLL` | `PAYROLL_RUNS` |
| `SEQ_PAYROLL_DETAIL` | `PKG_PAYROLL` | `PAYROLL_DETAILS` |
| `SEQ_TAX_BRACKET` | seed scripts | `TAX_BRACKETS` |
| `SEQ_LEAVE_TYPE` | seed scripts | `LEAVE_TYPES` |
| `SEQ_LEAVE_BALANCE` | `PKG_LEAVE` | `LEAVE_BALANCES` |
| `SEQ_LEAVE_REQUEST` | `PKG_LEAVE` | `LEAVE_REQUESTS` |
| `SEQ_LEAVE_ACCRUAL` | `PKG_LEAVE` | `LEAVE_ACCRUAL_LOG` |
| `SEQ_HOLIDAY` | seed scripts | `HOLIDAYS` |
| `SEQ_REVIEW_CYCLE` | `PKG_PERFORMANCE` | `REVIEW_CYCLES` |
| `SEQ_PERF_REVIEW` | `PKG_PERFORMANCE` | `PERFORMANCE_REVIEWS` |
| `SEQ_PERF_GOAL` | `PKG_PERFORMANCE` | `PERFORMANCE_GOALS` |
| `SEQ_AUDIT` | `PKG_AUDIT` | `AUDIT_LOG` |
| `SEQ_NOTIFICATION` | `PKG_NOTIFICATION` | `NOTIFICATION_QUEUE` |
| `SEQ_USER_SESSION` | `PKG_SECURITY` | `USER_SESSIONS` |
| `SEQ_SYSTEM_PARAM` | seed scripts | `SYSTEM_PARAMETERS` |
| `SEQ_LOOKUP` | seed scripts | `LOOKUP_VALUES` |

---

## 12. Dependency Risk Summary

| Risk | Description | Components |
|---|---|---|
| **Circular Dependency** | `PKG_EMPLOYEE` <-> `PKG_PAYROLL` creates deployment coupling and prevents independent testing | `PKG_EMPLOYEE.pkb:275`, `PKG_PAYROLL.pkb` |
| **God Package** | `PKG_EMPLOYEE` (967 lines) and `PKG_PAYROLL` (898 lines) contain too much logic | Multiple modules depend on both |
| **Validation Drift** | `HRMS_VALIDATION_LIB` (client) and `PKG_VALIDATION` (server) implement overlapping but divergent logic | Email validation differs |
| **Trigger-Package Duplication** | Business rules duplicated across Forms triggers, DB triggers, and packages | `TRG_EMP_BEFORE_INSERT` vs `PKG_EMPLOYEE.create_employee` |
| **Hard-Coded Config** | Tax brackets, SMTP servers, fiscal year start, encryption keys embedded in package bodies | `PKG_PAYROLL`, `PKG_NOTIFICATION`, `PKG_SECURITY`, `PKG_REPORTING` |
| **External File Coupling** | Integration relies on UTL_FILE + Oracle Directory objects + cleartext FTP credentials | `PKG_INTEGRATION`, `PKG_PAYROLL` (pay register) |
| **Central Point of Failure** | `PKG_COMMON` is called by every package; any issue cascades everywhere | All packages |
