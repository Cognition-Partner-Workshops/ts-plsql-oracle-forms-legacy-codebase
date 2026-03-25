# HRMS Module Migration Ordering

## Overview

This document defines the safe migration sequence for the HRMS Oracle Forms/PL/SQL application, respecting package dependencies, data relationships, and business continuity requirements. The ordering is derived from a dependency analysis of all 11 PL/SQL packages, 6 Forms modules, 2 PLL libraries, and 30 database tables.

---

## 1. Package Dependency Graph

### 1.1 Direct Dependencies

```
PKG_COMMON        -> (none)                              [Base - Tier 0]
PKG_AUDIT          -> (none)                              [Base - Tier 0]
PKG_VALIDATION     -> PKG_COMMON                          [Tier 1]
PKG_NOTIFICATION   -> PKG_COMMON                          [Tier 1]
PKG_SECURITY       -> PKG_COMMON, PKG_AUDIT               [Tier 1]
PKG_EMPLOYEE       -> PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION, PKG_PAYROLL  [Tier 2*]
PKG_PAYROLL        -> PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION [Tier 2*]
PKG_LEAVE          -> PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION [Tier 3]
PKG_PERFORMANCE    -> PKG_EMPLOYEE, PKG_COMMON, PKG_AUDIT, PKG_NOTIFICATION [Tier 3]
PKG_REPORTING      -> PKG_EMPLOYEE, PKG_PAYROLL, PKG_COMMON                 [Tier 4]
PKG_INTEGRATION    -> PKG_COMMON, PKG_PAYROLL, PKG_EMPLOYEE                 [Tier 4]
```

> **\* Circular Dependency:** PKG_EMPLOYEE and PKG_PAYROLL have a mutual dependency.
> - PKG_EMPLOYEE calls `PKG_PAYROLL.create_salary_record()` during create, promote, and rehire operations.
> - PKG_PAYROLL calls `PKG_EMPLOYEE.is_active()` for employee validation during payroll calculation.

### 1.2 Visual Dependency Diagram

```
                    +--------------+     +-----------+
                    | PKG_COMMON   |     | PKG_AUDIT |
                    +------+-------+     +-----+-----+
                           |                   |
            +--------------+---+---+-----------+--------+
            |              |       |                    |
     +------+------+ +----+----+ +------+--------+     |
     | PKG_VALID.  | | PKG_NOT.| | PKG_SECURITY  |     |
     +------+------+ +----+----+ +---------------+     |
            |              |                            |
            +---------+----+---+------------------------+
                      |        |
              +-------+------+ +-------+------+
              | PKG_EMPLOYEE |<-->| PKG_PAYROLL | (CIRCULAR)
              +------+-------+ +------+-------+
                     |                 |
          +----------+---------+       |
          |          |         |       |
   +------+--+ +----+------+ ++---------+---+
   |PKG_LEAVE| |PKG_PERF.  | |PKG_REPORTING |
   +---------+ +-----------+ +------+-------+
                                     |
                              +------+--------+
                              |PKG_INTEGRATION|
                              +---------------+
```

### 1.3 Forms Module Dependencies

| Form Module | PL/SQL Packages Used | PLL Libraries | Other Forms |
|------------|---------------------|---------------|-------------|
| HRMS_LOGIN | PKG_SECURITY, PKG_EMPLOYEE | HRMS_COMMON_LIB | Opens: HRMS_MENU |
| HRMS_MENU | PKG_SECURITY | HRMS_COMMON_LIB | Opens: all other forms |
| HRMS_EMPLOYEE | PKG_EMPLOYEE, PKG_VALIDATION, PKG_SECURITY | HRMS_COMMON_LIB, HRMS_VALIDATION_LIB | Opened from: HRMS_MENU |
| HRMS_PAYROLL | PKG_PAYROLL, PKG_SECURITY | HRMS_COMMON_LIB | Opened from: HRMS_MENU |
| HRMS_LEAVE | PKG_LEAVE, PKG_SECURITY | HRMS_COMMON_LIB, HRMS_VALIDATION_LIB | Opened from: HRMS_MENU |
| HRMS_PERFORMANCE | PKG_PERFORMANCE, PKG_SECURITY | HRMS_COMMON_LIB | Opened from: HRMS_MENU |

### 1.4 Database Table Dependencies (Foreign Keys)

```
Core Layer (no FK dependencies on other HRMS tables):
  LOCATIONS, JOB_GRADES, LOOKUP_VALUES, SYSTEM_PARAMETERS

Reference Layer (depends on Core):
  JOB_TITLES -> JOB_GRADES
  DEPARTMENTS -> LOCATIONS (via LOCATION_CODE), self-ref (PARENT_DEPT_ID)

Employee Layer (depends on Reference):
  EMPLOYEES -> DEPARTMENTS, JOB_TITLES, LOCATIONS, EMPLOYEES (self-ref MANAGER_EMP_ID)
  EMPLOYEE_HISTORY -> EMPLOYEES
  EMPLOYEE_DEPENDENTS -> EMPLOYEES
  EMERGENCY_CONTACTS -> EMPLOYEES

Payroll Layer (depends on Employee):
  SALARY_RECORDS -> EMPLOYEES
  PAY_ELEMENTS -> (none)
  EMPLOYEE_PAY_ELEMENTS -> EMPLOYEES, PAY_ELEMENTS
  PAY_PERIODS -> (none)
  PAYROLL_RUNS -> PAY_PERIODS
  PAYROLL_DETAILS -> PAYROLL_RUNS, EMPLOYEES, PAY_ELEMENTS
  TAX_BRACKETS -> (none)
  EMPLOYEE_TAX_INFO -> EMPLOYEES
  EMPLOYEE_BANK_ACCOUNTS -> EMPLOYEES

Leave Layer (depends on Employee):
  LEAVE_TYPES -> (none)
  LEAVE_BALANCES -> EMPLOYEES, LEAVE_TYPES
  LEAVE_REQUESTS -> EMPLOYEES, LEAVE_TYPES
  LEAVE_ACCRUAL_LOG -> EMPLOYEES, LEAVE_TYPES
  HOLIDAYS -> (none)

Performance Layer (depends on Employee):
  REVIEW_CYCLES -> (none)
  PERFORMANCE_REVIEWS -> REVIEW_CYCLES, EMPLOYEES
  PERFORMANCE_GOALS -> PERFORMANCE_REVIEWS, EMPLOYEES

System Layer (depends on Employee):
  AUDIT_LOG -> (none, uses table_name + record_id loosely)
  NOTIFICATION_QUEUE -> (none, uses recipient_emp_id loosely)
  USER_SESSIONS -> EMPLOYEES
```

---

## 2. Recommended Migration Sequence

### Principles

1. **Migrate dependencies before dependents** - never migrate a module before its prerequisites are available.
2. **Resolve circular dependencies via facade/interface** - the PKG_EMPLOYEE <-> PKG_PAYROLL cycle requires an abstraction boundary.
3. **Prioritize authentication** - every module depends on the security layer.
4. **Maximize parallel work** - modules at the same tier can be migrated concurrently.
5. **Deliver value incrementally** - sequence for earliest user-visible improvement.

---

### Wave 0: Infrastructure Foundation (Weeks 1-4)

**Purpose:** Establish the modern runtime environment, shared libraries, and anti-corruption layer.

| # | Component | Rationale | Effort |
|---|-----------|-----------|--------|
| 0.1 | **Project scaffolding** (Spring Boot + React) | Foundation for all subsequent modules | 1 week |
| 0.2 | **Common utilities** (replaces PKG_COMMON) | Base dependency for every package; logging, date utils, formatting, config | 1 week |
| 0.3 | **Audit framework** (replaces PKG_AUDIT) | Cross-cutting concern needed by all write operations | 0.5 weeks |
| 0.4 | **Validation framework** (replaces PKG_VALIDATION + HRMS_VALIDATION_LIB) | Consolidate client/server validation into single source of truth | 0.5 weeks |
| 0.5 | **Notification service** (replaces PKG_NOTIFICATION) | Async message queue infrastructure; decouples from all callers | 1 week |
| 0.6 | **Anti-corruption layer / API gateway** | Routing layer that allows legacy and modern systems to coexist | 1 week |

**Deliverables:**
- Spring Boot app with health checks, logging, config management
- React app shell with routing, auth context, error boundary
- Shared validation library (Zod schemas)
- Notification microservice with message queue
- API gateway routing rules

**Database changes:** None. Modern services read/write to the same Oracle DB via JDBC.

---

### Wave 1: Authentication & Authorization (Weeks 5-8)

**Purpose:** Establish the security perimeter. Every other module depends on this.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 1.1 | **Auth service** (Spring Security + JWT) | PKG_SECURITY.authenticate(), is_session_valid() | PKG_COMMON (Wave 0) |
| 1.2 | **Login page** (React) | HRMS_LOGIN form | Auth service |
| 1.3 | **RBAC permission service** | PKG_SECURITY.has_permission() | Auth service, Employee data (read-only from legacy DB) |
| 1.4 | **Password migration utility** | MD5 hash -> bcrypt migration | Auth service |
| 1.5 | **Session management** | USER_SESSIONS table -> JWT tokens | Auth service |
| 1.6 | **Main navigation shell** (React) | HRMS_MENU form + HRMS_MENU.mmb | Auth service, RBAC |

**Critical Path:** Auth must be complete before any other module's UI can be migrated.

**Coexistence Strategy:**
- Modern auth service issues JWT tokens for new React UI.
- Legacy Forms continue using PKG_SECURITY for existing sessions.
- A compatibility shim validates JWT tokens in the legacy DB session table for mixed-mode operation.

**Database changes:**
- Add `PASSWORD_BCRYPT` column to credentials table (or new `USER_CREDENTIALS` table).
- Add `JWT_ENABLED` flag to `SYSTEM_PARAMETERS`.

---

### Wave 2: Employee Management - Read Path (Weeks 9-13)

**Purpose:** Migrate the highest-traffic module's read operations. Forms continue handling writes.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 2.1 | **Employee JPA entities & repository** | EMPLOYEES table access in PKG_EMPLOYEE | Wave 0 (common utils) |
| 2.2 | **Employee read APIs** | PKG_EMPLOYEE: get_employee, search_employees, get_org_chart, get_direct_reports, get_headcount_by_dept | Wave 1 (auth) |
| 2.3 | **Employee profile page** (React, read-only) | HRMS_EMPLOYEE form (view mode) | Wave 2.2 |
| 2.4 | **Organization chart** (React) | PKG_EMPLOYEE.get_org_chart (with pagination fix) | Wave 2.2 |
| 2.5 | **Employee search** (React) | PKG_EMPLOYEE.search_employees (with parameterized queries, fixing SQL injection) | Wave 2.2 |
| 2.6 | **Department/Job/Location reference APIs** | LOVs in HRMS_EMPLOYEE | Wave 0 |

**Why read-first:** Separating reads from writes avoids the PKG_EMPLOYEE <-> PKG_PAYROLL circular dependency. Read operations don't trigger salary record creation.

**Coexistence Strategy:**
- React app displays employee data from the same Oracle DB.
- Write operations (create, update, transfer, promote, terminate) remain on legacy Forms.
- Users can toggle between React (view) and Forms (edit) during transition.

---

### Wave 3: Leave Management (Weeks 11-16)

**Purpose:** First complete module migration (read + write). Leave management has clear boundaries and limited dependencies.

> **Can run in parallel with Wave 2** - different team/developer.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 3.1 | **Leave JPA entities & repository** | LEAVE_TYPES, LEAVE_BALANCES, LEAVE_REQUESTS, HOLIDAYS tables | Wave 0 |
| 3.2 | **Leave service** (business logic) | PKG_LEAVE: submit, approve, reject, cancel, balance checks | Wave 1 (auth), Wave 2.1 (Employee entity for validation) |
| 3.3 | **Leave balance APIs** | PKG_LEAVE.get_leave_balance() | Wave 3.2 |
| 3.4 | **Leave request form** (React) | HRMS_LEAVE form (TP_NEW_REQUEST) | Wave 3.2, Wave 3.3 |
| 3.5 | **Leave approval workflow** (React) | HRMS_LEAVE form (approve/reject buttons) | Wave 3.2 |
| 3.6 | **Team calendar** (React) | HRMS_LEAVE form (TP_TEAM) | Wave 3.2 |
| 3.7 | **Leave accrual batch job** | PKG_LEAVE.run_monthly_accrual() | Wave 3.2 (Spring Batch) |
| 3.8 | **Carryover processing** | PKG_LEAVE.process_carryover(), expire_carryover() | Wave 3.2 |

**Bug Fixes During Migration:**
- Fix half-day overlap detection (check AM/PM period, not just dates)
- Make carryover expiry idempotent (add `LAST_EXPIRY_RUN_DATE` tracking)
- Handle observed holidays (add `OBSERVED_DATE` column to HOLIDAYS)

**Decommission:** Legacy HRMS_LEAVE form can be retired after Wave 3 validation.

---

### Wave 4: Performance Reviews (Weeks 14-18)

**Purpose:** Second complete module migration. Low-risk, high-UX-improvement opportunity.

> **Can run in parallel with Wave 3** - different team/developer.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 4.1 | **Performance JPA entities** | REVIEW_CYCLES, PERFORMANCE_REVIEWS, PERFORMANCE_GOALS | Wave 0 |
| 4.2 | **Performance service** | PKG_PERFORMANCE: cycle management, review workflow, goal tracking | Wave 1 (auth), Wave 2.1 (Employee entity) |
| 4.3 | **Review cycle management** (React) | HRMS_PERFORMANCE form (TP_CYCLES) | Wave 4.2 |
| 4.4 | **Self-assessment & manager review** (React) | HRMS_PERFORMANCE form (TP_REVIEWS) with rich text editors | Wave 4.2 |
| 4.5 | **Goal tracking** (React) | HRMS_PERFORMANCE form (TP_GOALS) with progress visualization | Wave 4.2 |
| 4.6 | **Rating distribution dashboard** (React) | PKG_PERFORMANCE.get_rating_distribution() | Wave 4.2 |

**UX Improvements:**
- Replace CLOB text areas with rich text editors (Quill/TipTap)
- Add interactive goal progress visualization
- Build rating calibration dashboard not present in legacy

**Decommission:** Legacy HRMS_PERFORMANCE form can be retired after Wave 4 validation.

---

### Wave 5: Resolve Circular Dependency & Employee Write Path (Weeks 16-22)

**Purpose:** Break the PKG_EMPLOYEE <-> PKG_PAYROLL circular dependency and enable full employee management writes.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 5.1 | **Salary management interface** | Extract salary operations into a `SalaryService` interface/facade | Wave 0 |
| 5.2 | **Employee write APIs** | PKG_EMPLOYEE: create_employee, update_employee | Wave 2, Wave 5.1 |
| 5.3 | **Transfer workflow** | PKG_EMPLOYEE.transfer_employee() | Wave 5.2 |
| 5.4 | **Promotion workflow** | PKG_EMPLOYEE.promote_employee() | Wave 5.2, Wave 5.1 (salary record creation) |
| 5.5 | **Termination workflow** | PKG_EMPLOYEE.terminate_employee() | Wave 5.2, Wave 3 (leave cancellation) |
| 5.6 | **Rehire workflow** | PKG_EMPLOYEE.rehire_employee() | Wave 5.2, Wave 5.1 |
| 5.7 | **Employee number generation** | PKG_EMPLOYEE.generate_emp_number() - fix race condition | Wave 5.2 |
| 5.8 | **Employee form** (React, full CRUD) | HRMS_EMPLOYEE form (all tab pages, write mode) | Wave 5.2-5.6 |

**Breaking the Circular Dependency:**

```
BEFORE (circular):
  PKG_EMPLOYEE --calls--> PKG_PAYROLL.create_salary_record()
  PKG_PAYROLL  --calls--> PKG_EMPLOYEE.is_active()

AFTER (facade pattern):
  EmployeeService --uses--> SalaryService (interface)
  PayrollService  --uses--> EmployeeQueryService (interface)

  SalaryServiceImpl implements SalaryService (calls PayrollService internally)
  EmployeeQueryServiceImpl implements EmployeeQueryService (calls EmployeeService internally)
```

The key insight is that:
- Employee's dependency on Payroll is limited to `create_salary_record()` (salary management).
- Payroll's dependency on Employee is limited to `is_active()` (read-only validation).

Extract these into thin interfaces that can be injected without creating a cycle.

**Bug Fixes During Migration:**
- Replace `MAX()+1` employee number generation with sequence-based atomic operation
- Replace dynamic SQL string concatenation with parameterized queries (JPA Specifications)
- Add proper optimistic locking (`@Version` column) instead of `SELECT FOR UPDATE NOWAIT`

**Decommission:** Legacy HRMS_EMPLOYEE form can be retired after Wave 5 validation.

---

### Wave 6: Payroll Processing (Weeks 20-28)

**Purpose:** Migrate the highest-risk module with conservative dual-run validation.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 6.1 | **Tax calculation engine** | PKG_PAYROLL: calculate_federal_tax, calculate_state_tax, calculate_fica, calculate_medicare | Wave 0 (configurable brackets from DB) |
| 6.2 | **Pay period management** | PKG_PAYROLL: create_pay_periods, close_pay_period, get_current_period | Wave 1 (auth) |
| 6.3 | **Salary record management** | PKG_PAYROLL: create_salary_record, get_current_salary, get_salary_as_of | Wave 5.1 (interface) |
| 6.4 | **Payroll run engine** (Spring Batch) | PKG_PAYROLL: create_payroll_run, calculate_payroll, calculate_employee_pay | Wave 6.1, 6.2, 6.3, Wave 5 (Employee) |
| 6.5 | **Payroll approval workflow** | PKG_PAYROLL: approve_payroll, reverse_payroll | Wave 6.4 |
| 6.6 | **Payslip & pay register** | PKG_PAYROLL: get_payslip, get_ytd_earnings, generate_pay_register | Wave 6.4 |
| 6.7 | **Payroll UI** (React) | HRMS_PAYROLL form (all tabs) | Wave 6.2-6.6 |
| 6.8 | **Dual-run validation** | Run both legacy and modern payroll in parallel and compare results | Wave 6.4 |

**Dual-Run Strategy:**
1. **Month 1-2:** Modern engine calculates payroll for all employees; results compared to legacy but NOT used for payment.
2. **Month 3:** If variance < 0.01% for 2 consecutive periods, switch primary to modern with legacy as verification.
3. **Month 4:** Decommission legacy payroll calculation (keep legacy data for historical queries).

**Bug Fixes During Migration:**
- Move tax brackets from hard-coded constants to configurable DB table with annual refresh
- Replace cursor-loop processing with Spring Batch chunk-oriented processing
- Fix partial commit issue (atomic payroll run with proper rollback)
- Fix overtime calculation to account for holidays
- Fix YTD reset for mid-year hires

**Decommission:** Legacy HRMS_PAYROLL form can be retired after dual-run validation passes.

---

### Wave 7: Reporting & Analytics (Weeks 22-26)

**Purpose:** Replace legacy Oracle Reports with modern dashboards.

> **Can start in parallel with Wave 6** - reporting reads only, no write dependencies.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 7.1 | **Report data service** | PKG_REPORTING: all report procedures | Wave 2 (Employee), Wave 6 (Payroll) for complete data |
| 7.2 | **Headcount dashboard** (React) | PKG_REPORTING.headcount_report() | Wave 7.1 |
| 7.3 | **Compensation analytics** (React) | PKG_REPORTING.compensation_summary() | Wave 7.1 |
| 7.4 | **Turnover report** (React) | PKG_REPORTING.turnover_report() | Wave 7.1 |
| 7.5 | **Leave utilization report** (React) | PKG_REPORTING.leave_utilization_report() | Wave 3 (Leave), Wave 7.1 |
| 7.6 | **Payroll summary** (React) | PKG_REPORTING.payroll_summary_report() | Wave 6 (Payroll), Wave 7.1 |
| 7.7 | **EEO compliance report** (React/PDF) | PKG_REPORTING.eeo_compliance_report() | Wave 7.1 |
| 7.8 | **Reporting table refresh** | PKG_REPORTING.refresh_reporting_tables() -> materialized views or CQRS | Wave 7.1 |

**Bug Fixes:**
- Make fiscal year start configurable (remove hard-coded Oct 1)
- Replace nightly batch refresh with near-real-time materialized views or change data capture

---

### Wave 8: External Integrations (Weeks 26-30)

**Purpose:** Modernize integration patterns from flat files to APIs.

| # | Component | Replaces | Dependencies |
|---|-----------|----------|-------------|
| 8.1 | **GL journal integration** | PKG_INTEGRATION.generate_gl_journal() | Wave 6 (Payroll) |
| 8.2 | **Benefits feed** | PKG_INTEGRATION.export_benefits_feed() | Wave 5 (Employee) |
| 8.3 | **Time & attendance import** | PKG_INTEGRATION.import_time_attendance() | Wave 5 (Employee), Wave 6 (Payroll) |
| 8.4 | **Org structure sync** | PKG_INTEGRATION.sync_org_structure() | Wave 5 (Employee) |

**Security Fixes:**
- Replace cleartext FTP credentials with SFTP + key-based auth or API tokens
- Replace UTL_FILE flat file exchange with REST API calls
- Add retry logic with exponential backoff
- Replace ADP-specific format with standard HR-XML or API integration

---

### Wave 9: Legacy Decommission (Weeks 28-32)

**Purpose:** Retire Oracle Forms and clean up legacy artifacts.

| # | Task | Details |
|---|------|---------|
| 9.1 | Remove Forms server | Shut down Oracle Forms/Reports server after all modules migrated |
| 9.2 | Remove PLL libraries | No longer needed (HRMS_COMMON_LIB, HRMS_VALIDATION_LIB) |
| 9.3 | Drop legacy packages | PKG_* packages can be dropped after verification period |
| 9.4 | Drop legacy triggers | Database triggers replaced by JPA lifecycle callbacks |
| 9.5 | Clean up SYSTEM_PARAMETERS | Remove Forms-specific parameters (e.g., Forms module names) |
| 9.6 | Clean up USER_SESSIONS table | No longer needed if using JWT |
| 9.7 | Database migration (optional) | Migrate from Oracle 19c to PostgreSQL if license elimination is a goal |
| 9.8 | Archive legacy code | Move Forms XML, PLL source, and menu module to an archive branch |

---

## 3. Migration Timeline Summary

```
Week  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
      |--Wave 0--|  |--Wave 1--|  |---Wave 2----|
                                  |------Wave 3-------|
                                              |------Wave 4-------|
                                                          |--------Wave 5---------|
                                                                      |----------Wave 6------------|
                                                                              |-Wave 7--|
                                                                                            |Wave 8-|
                                                                                                |W9-|
```

**Parallel Tracks:**
- **Track A (Core):** Wave 0 -> Wave 1 -> Wave 2 -> Wave 5 -> Wave 6
- **Track B (Self-Service):** Wave 3 (Leave) + Wave 4 (Performance) can run in parallel with Track A
- **Track C (Analytics):** Wave 7 (Reporting) can start as soon as sufficient data modules are migrated

---

## 4. Migration Gate Criteria

Before moving from one wave to the next, the following must be satisfied:

| Gate | Criteria |
|------|----------|
| **Functional Completeness** | All features in the wave are implemented and unit tested |
| **Data Consistency** | Data written by modern services is readable by legacy Forms (and vice versa) during coexistence |
| **Performance** | Response times within 20% of legacy system (or better) |
| **Security** | Authentication and authorization work correctly for migrated modules |
| **Regression** | No regressions in unmigrated modules still running on legacy Forms |
| **User Acceptance** | Key stakeholders have validated the migrated module in UAT |
| **Monitoring** | Logging, alerting, and dashboards are in place for the migrated module |
| **Rollback Plan** | Documented and tested rollback procedure exists for the wave |

---

## 5. Risk Mitigation for Ordering Dependencies

| Risk | Module | Mitigation |
|------|--------|-----------|
| Circular dependency blocks Employee/Payroll migration | PKG_EMPLOYEE <-> PKG_PAYROLL | Resolve in Wave 5 via facade/interface pattern before migrating write operations |
| Auth migration disrupts all users | PKG_SECURITY | Coexistence mode: legacy Forms auth remains active alongside modern JWT |
| Leave migration breaks balance calculations | PKG_LEAVE | Run balance reconciliation job nightly during Wave 3 transition |
| Payroll calculation variance | PKG_PAYROLL | Mandatory dual-run period (Wave 6.8) before cutover |
| Reporting data staleness during migration | PKG_REPORTING | Maintain legacy nightly refresh until modern materialized views are proven |
| Integration partner impact | PKG_INTEGRATION | Coordinate with external partners (GL system, ADP, T&A) before Wave 8 |
| Database schema changes break legacy | Schema DDL | All schema changes must be backward-compatible during coexistence |
