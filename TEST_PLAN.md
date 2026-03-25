# Test Plan

> **System**: HRMS (Human Resource Management System) v4.2  
> **Platform**: Oracle Forms 12c / Oracle Database 19c  
> **Schema**: HRMS  
> **Goal**: Define a test suite that achieves full functional coverage of the legacy Oracle Forms, PLL, PL/SQL, trigger, and view estate while also producing executable equivalence scenarios for the modernization test harness.

---

## 1. Objectives

This plan is for **test design**, not implementation. The target is 100% coverage of the legacy estate at the level that matters for modernization:

1. **Every public package procedure/function is exercised**.
2. **Every trigger is fired intentionally**.
3. **Every view is validated for correctness and known drift**.
4. **Every shared PLL routine and form workflow is covered**.
5. **Known defects and vulnerabilities become explicit regression tests**.
6. **Cross-module side effects** (audit, notifications, history, balances, payroll details, session state) are verified.
7. **Legacy behavior is captured as executable specifications** in the YAML scenario format used by the modernization repo's `test-harness/`.

---

## 2. Coverage Definition

"100% coverage" for this codebase means all of the following are covered:

| Layer | Coverage requirement |
|---|---|
| Oracle Forms XML | Happy path, validation, navigation, error handling, trigger-driven workflows |
| PLL libraries | All shared routines and their side effects |
| PL/SQL packages | Every public procedure/function, including success, failure, boundary, and side-effect paths |
| Triggers | Insert/update/delete trigger firing, error codes, audit/history side effects |
| Views | Result correctness, filters, aggregations, joins, edge conditions |
| Batch jobs | Idempotency, partial failure, rerun behavior, cutoff/date logic |
| Security | Authentication, authorization, encryption, session expiry, abuse cases |
| Modernization harness | Scenario parity for legacy package calls vs modern REST endpoints |

---

## 3. Test Strategy

### 3.1 Test layers

1. **Package unit tests**
   - Execute individual package entry points with controlled seed data.
   - Verify return values, raised errors, table mutations, and side effects.

2. **Database integration tests**
   - Validate interactions across packages, triggers, views, and tables.
   - Required for employee lifecycle, payroll, leave, performance, and reporting.

3. **Forms/PLL workflow tests**
   - Validate client-side behavior that can drift from server-side logic.
   - Focus on login, employee maintenance, leave approval, payroll, and shared toolbar behavior.

4. **Batch/regression tests**
   - Validate monthly accrual, carryover, payroll runs, reporting refresh, and queue processing.

5. **Security/abuse tests**
   - Validate vulnerable paths intentionally documented in the codebase.

6. **Legacy-to-modern equivalence tests**
   - Capture legacy outputs as golden results using the YAML scenario format in `uc-legacy-modernization-oracle-forms-to-java/test-harness/`.

### 3.2 Assertion types

Each test case should assert some combination of:

- Returned scalar/record/cursor output
- Raised Oracle error code and message
- Insert/update/delete effects in base tables
- Audit trail row created or not created
- History row created or not created
- Notification queue row created or not created
- Autonomous transaction commit behavior
- Idempotency / duplicate-run handling
- Concurrency correctness
- Legacy defect reproduction (document current behavior)

---

## 4. Environments and Data Prerequisites

### 4.1 Required environments

- **Oracle 19c integration database** with HRMS schema
- Seed data from:
  - `data/seed/01_reference_data.sql`
  - `data/seed/02_employee_data.sql`
- Oracle Forms runtime for client-side workflow validation
- Scheduler-capable environment for queue/accrual/payroll batch tests
- File-system-backed Oracle directory objects for UTL_FILE tests:
  - `PAYROLL_OUTPUT`
  - `GL_FEED_OUT`
  - `BENEFITS_FEED_OUT`
  - `TIME_ATTENDANCE_IN`

### 4.2 Test data fixtures

Create reusable fixtures for:

- Active employee with manager
- Terminated employee eligible for rehire
- Employee with dependents and emergency contacts
- Employees in multiple grades/states/locations
- Employee with active salary and pay elements
- Employee near FICA wage base and Medicare surcharge threshold
- Employee with leave balances, pending leave, approved leave, carryover, and half-day requests
- Employees in deep reporting hierarchy (>10 levels and >500 nodes synthetic)
- Review cycle with draft/open/closed states
- Notification queue rows in pending/failed/sent states
- Session rows in valid/expired/logged-out states
- SYSTEM_PARAMETERS rows for configuration and integration status

### 4.3 Isolation rules

- Every destructive test should run inside a transaction and roll back unless autonomous commit behavior is the thing being tested.
- Batch tests that commit by design should run on disposable schemas or reset fixtures afterward.
- Concurrency tests must use at least two DB sessions.

---

## 5. Modernization Test Harness Alignment

The modernization repo already defines the harness shape in `test-harness/README.md` and sample YAML scenarios:

```yaml
name: employee-crud
module: employee
legacy_package: PKG_EMPLOYEE
modern_endpoint: /api/employees
steps:
  - name: Create a new employee
    action: create
    input: {...}
    expect: {...}
    tolerance: {...}
    save_as: new_employee
```

### 5.1 Harness rules to preserve

- One YAML file per business scenario.
- Required fields: `name`, `description`, `module`, `legacy_package`, `modern_endpoint`, `steps`.
- Step fields: `name`, `action`, `input`, `expect`.
- Optional fields: `tolerance`, `save_as`.
- Placeholder reuse via `{{saved_object.field}}`.
- Tolerance handling for numeric outputs (for payroll rounding).
- Wildcards for generated values like `EMP-*`.

### 5.2 Scenario families to add

Create these new scenario files in the modernization harness when implementation begins:

1. `common-utilities.yaml`
2. `audit-history.yaml`
3. `validation-rules.yaml`
4. `notification-queue.yaml`
5. `security-auth.yaml` (expand existing)
6. `security-session.yaml`
7. `employee-crud.yaml` (expand existing)
8. `employee-hierarchy.yaml`
9. `employee-rehire.yaml`
10. `employee-search-injection.yaml`
11. `payroll-periods.yaml`
12. `payroll-calculation.yaml` (expand existing)
13. `payroll-tax-boundaries.yaml`
14. `leave-workflow.yaml` (expand existing)
15. `leave-accrual-carryover.yaml`
16. `leave-overlap-halfday.yaml`
17. `performance-cycle.yaml`
18. `performance-goals.yaml`
19. `reporting-outputs.yaml`
20. `integration-file-outputs.yaml`
21. `triggers-and-side-effects.yaml`
22. `views-regression.yaml`
23. `forms-validation-drift.yaml`
24. `forms-navigation-and-toolbar.yaml`

---

## 6. Package Coverage Catalog

The tables below define the minimum test inventory. Each routine needs at least:

- **H** = happy path
- **N** = negative/error path
- **B** = boundary/null/default path
- **S** = side effects / downstream tables / audit / notifications
- **C** = concurrency / rerun / timing path where applicable

### 6.1 PKG_COMMON

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `log_error` | COM-01, COM-02 | Autonomous transaction commits even when caller rolls back; row contains module/location/message/user |
| `log_info` | COM-03, COM-04 | Informational log insert; autonomous behavior |
| `set_param` | COM-05, COM-06 | Insert new parameter vs update existing parameter |
| `get_param` | COM-07, COM-08 | Existing parameter returns value; missing parameter returns `NULL` |
| `get_param_number` | COM-09, COM-10 | Numeric parse success; invalid/missing value handling |
| `get_param_date` | COM-11, COM-12 | Date parse success; invalid/missing value handling |
| `business_days_between` | COM-13, COM-14, COM-15 | Same day, weekend spanning, holiday spanning |
| `add_business_days` | COM-16, COM-17, COM-18 | Positive increment, zero increment, holiday/weekend skip |
| `get_fiscal_year` | COM-19, COM-20 | Boundary around Oct 1 fiscal cutoff |
| `get_fiscal_quarter` | COM-21, COM-22 | Quarter mapping across all fiscal quarters |
| `format_phone` | COM-23, COM-24, COM-25 | 10-digit, 11-digit, invalid-length input |
| `format_ssn_masked` | COM-26, COM-27 | Proper masking, null/short input |
| `format_currency` | COM-28, COM-29 | Positive/negative/zero formatting |
| `format_name` | COM-30, COM-31 | Mixed-case normalization, null handling |
| `is_valid_email` | COM-32, COM-33 | Standard valid email; malformed email |
| `is_valid_phone` | COM-34, COM-35 | Valid 10/11-digit phones; invalid symbols/length |
| `is_valid_ssn` | COM-36, COM-37 | Valid SSN; zero-group rejection |

### 6.2 PKG_AUDIT

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `log_action` | AUD-01, AUD-02, AUD-03 | Insert with old/new payloads; `SYS_CONTEXT` session/IP capture; autonomous commit survives caller rollback |
| `purge_old_records` | AUD-04, AUD-05 | Deletes only rows older than threshold; keeps recent rows |
| `get_change_history` | AUD-06, AUD-07 | Cursor contains expected change chronology; empty result for missing record |

### 6.3 PKG_VALIDATION

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `validate_date_range` | VAL-01, VAL-02, VAL-03 | Valid range; end before start; null handling |
| `validate_salary_for_grade` | VAL-04, VAL-05, VAL-06, VAL-07 | In range returns `NULL`; below minimum; above maximum; invalid grade |
| `validate_email_format` | VAL-08, VAL-09 | Delegates to `PKG_COMMON.is_valid_email` correctly |
| `validate_phone_format` | VAL-10, VAL-11 | Delegates to `PKG_COMMON.is_valid_phone` correctly |
| `validate_emp_number_format` | VAL-12, VAL-13 | `EMP-000001` accepted; malformed numbers rejected |
| `is_future_date` | VAL-14, VAL-15 | Today vs future date |
| `is_business_day` | VAL-16, VAL-17, VAL-18 | Weekday, weekend, exact holiday match |
| `validate_required_fields` | VAL-19, VAL-20, VAL-21 | Complete EMPLOYEES record, missing field message, record-not-found |

### 6.4 PKG_NOTIFICATION

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `send_notification` | NOT-01, NOT-02, NOT-03 | Queue by emp ID resolves email; queue by explicit email; failures do not block business caller |
| `process_queue` | NOT-04, NOT-05, NOT-06 | Pending email marked sent; SMTP failure marks failed and increments retry; batch limit respected |
| `retry_failed` | NOT-07, NOT-08 | Failed rows below retry threshold reset to pending; rows at threshold remain failed |
| `cancel_notification` | NOT-09, NOT-10 | Pending notification cancelled; non-pending row unchanged |

### 6.5 PKG_SECURITY

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `authenticate` | SEC-01, SEC-02, SEC-03, SEC-04 | Valid credentials create session; invalid password rejected; inactive employee rejected; repeated failures show no lockout (document defect) |
| `logout` | SEC-05, SEC-06 | Session invalidated; already-invalid/missing session behavior |
| `is_session_valid` | SEC-07, SEC-08, SEC-09 | Fresh session valid; expired session invalid; logout invalidates immediately |
| `has_permission` | SEC-10, SEC-11, SEC-12 | Grade-based allow; grade-based deny; unsupported module/action behavior |
| `encrypt_ssn` | SEC-13, SEC-14 | Encryption produces non-plain output; deterministic key usage documented |
| `decrypt_ssn` | SEC-15, SEC-16 | Round-trip decrypt success; malformed cipher handling |
| `hash_password` | SEC-17, SEC-18 | Deterministic MD5 output; same password produces same hash (document vulnerability) |
| `change_password` | SEC-19, SEC-20, SEC-21 | Valid complexity accepted; weak password rejected; changed password authenticates successfully |

### 6.6 PKG_EMPLOYEE

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `create_employee` | EMP-01, EMP-02, EMP-03, EMP-04, EMP-05 | Normal create; invalid department; invalid manager/circular manager; optional salary path invokes `PKG_PAYROLL.create_salary_record`; audit/history side effects |
| `update_employee` | EMP-06, EMP-07, EMP-08 | Selective field updates; missing employee error; audit/history entries |
| `get_employee` | EMP-09, EMP-10 | Correct record mapping including salary; missing employee error |
| `get_employee_by_number` | EMP-11, EMP-12 | Lookup by valid number; missing employee |
| `search_employees` | EMP-13, EMP-14, EMP-15, EMP-16 | Filters by name/dept/status/date; combined filters; empty result; SQL injection payload demonstrates vulnerability without damaging data |
| `transfer_employee` | EMP-17, EMP-18, EMP-19, EMP-20 | Active employee transfer; non-active employee blocked with `-20012`; manager validation; history + audit rows |
| `promote_employee` | EMP-21, EMP-22, EMP-23 | Promotion updates job and salary; old salary absent path; salary change pct computed correctly |
| `terminate_employee` | EMP-24, EMP-25, EMP-26, EMP-27 | Termination sets status and flags; already terminated rejected; pending leave auto-cancelled; salary and pay elements deactivated; manager notification queued |
| `rehire_employee` | EMP-28, EMP-29, EMP-30 | Rehire restores active status; missing employee rejected; salary record recreated |
| `get_direct_reports` | EMP-31, EMP-32 | Returns active direct reports in order; empty set |
| `get_org_chart` | EMP-33, EMP-34, EMP-35 | Hierarchy returned for normal depth; `p_max_depth` honored; deep hierarchy timeout/performance risk documented |
| `get_headcount_by_dept` | EMP-36, EMP-37, EMP-38 | All active headcount; filtered department; as-of termination boundary |
| `get_tenure_years` | EMP-39, EMP-40 | Active employee uses `SYSDATE`; terminated employee uses termination date; missing employee returns `NULL` |
| `is_active` | EMP-41, EMP-42 | Active employee true; missing/inactive false |
| `validate_employee` | EMP-43, EMP-44, EMP-45 | Valid employee; missing required fields false; active status with `ACTIVE_FLAG != 'Y'` false |
| `emp_exists` | EMP-46, EMP-47 | Existing true; missing false |
| `generate_emp_number` | EMP-48, EMP-49, EMP-50 | Format `EMP-######`; concurrency collision reproduced; regression target to replace MAX+1 later |
| `set_session_context` | EMP-51, EMP-52 | Globals populated for valid employee; missing employee leaves dept null |

### 6.7 PKG_PAYROLL

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `create_salary_record` | PAY-01, PAY-02, PAY-03 | New active salary inserted; old active salary end-dated; invalid salary rejected |
| `get_current_salary` | PAY-04, PAY-05 | Current active salary returned; no active salary returns null/zero per implementation |
| `get_salary_as_of` | PAY-06, PAY-07, PAY-08 | Historical lookup before/after change; no record as of date |
| `create_pay_periods` | PAY-09, PAY-10, PAY-11 | Monthly periods; biweekly periods; unsupported frequency handling |
| `close_pay_period` | PAY-12, PAY-13 | Open period closes; already closed/nonexistent period behavior |
| `get_current_period` | PAY-14, PAY-15 | Current open period found; no current period |
| `create_payroll_run` | PAY-16, PAY-17 | Run created with pending status; invalid/closed period rejected |
| `calculate_payroll` | PAY-18, PAY-19, PAY-20, PAY-21 | Full run calculates all eligible employees; commits every 50 employees; partial failure leaves inconsistent run (document defect); status and totals updated |
| `calculate_employee_pay` | PAY-22, PAY-23, PAY-24, PAY-25 | Gross/tax/deduction detail rows inserted; deduction types handled; employee-specific elements applied; exception logging includes emp ID |
| `approve_payroll` | PAY-26, PAY-27 | Calculated run becomes approved; non-calculated run rejected with `-20103` |
| `reverse_payroll` | PAY-28, PAY-29 | Run/detail statuses marked reversed; audit row created |
| `calculate_federal_tax` | PAY-30 through PAY-36 | Single brackets, married-joint brackets, zero taxable income, allowances, additional withholding, each pay frequency annualization |
| `calculate_state_tax` | PAY-37, PAY-38, PAY-39 | Known-state rates, no-tax states, default state fallback |
| `calculate_fica` | PAY-40, PAY-41, PAY-42 | Below wage base, crossing wage base boundary, above wage base returns zero |
| `calculate_medicare` | PAY-43, PAY-44, PAY-45 | Base medicare, threshold crossing, above-threshold additional tax |
| `get_payslip` | PAY-46, PAY-47 | Aggregate totals correct for run; employee filter works |
| `get_ytd_earnings` | PAY-48, PAY-49, PAY-50 | Correct year aggregation; zero for no earnings; mid-year hire bug reproduction |
| `generate_pay_register` | PAY-51, PAY-52, PAY-53 | CSV file generated with header/detail/trailer semantics; file close on success; file close + logged error on failure |

### 6.8 PKG_LEAVE

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `submit_leave_request` | LEA-01, LEA-02, LEA-03, LEA-04, LEA-05 | Valid request inserted pending; insufficient balance rejected; overlap rejected; half-day total = `0.5`; tenure/date validations enforced |
| `approve_leave_request` | LEA-06, LEA-07, LEA-08 | Approved request updates status and balances; wrong approver rejected; notification/audit side effects |
| `reject_leave_request` | LEA-09, LEA-10 | Rejection requires comments; balance not decremented |
| `cancel_leave_request` | LEA-11, LEA-12, LEA-13 | Pending request cancel; approved request restores balance; repeated cancel behavior |
| `get_leave_balance` | LEA-14, LEA-15 | Formula returns opening + accrued - used + adjustment - pending; missing balance handling |
| `adjust_leave_balance` | LEA-16, LEA-17 | Positive and negative adjustment logged correctly |
| `initialize_balances` | LEA-18, LEA-19 | Initial rows created for all active leave types; rerun does not duplicate |
| `run_monthly_accrual` | LEA-20, LEA-21, LEA-22 | Accrual adds correct amount; max balance cap honored; commit every 100 employees and rerun safety |
| `process_carryover` | LEA-23, LEA-24, LEA-25 | Remaining leave carried forward; carryover max cap; expiry date set based on leave type policy |
| `expire_carryover` | LEA-26, LEA-27 | Expired balances zeroed and adjustment reduced; same-day double run reproduces double-subtract defect |
| `get_pending_requests` | LEA-28, LEA-29 | Approver queue contents and order; empty queue |
| `get_team_calendar` | LEA-30, LEA-31 | Approved/taken leave returned for date window; excluded statuses omitted |
| `calculate_business_days` | LEA-32, LEA-33, LEA-34 | Weekdays counted; holiday exclusion; observed-holiday defect documented |
| `check_leave_overlap` | LEA-35, LEA-36, LEA-37 | Overlap detection for pending/approved requests; exclude current request works; half-day overlap bug reproduced |

### 6.9 PKG_PERFORMANCE

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `create_review_cycle` | PER-01, PER-02 | Draft cycle created; audit row inserted |
| `open_review_cycle` | PER-03, PER-04 | Draft -> open works; non-draft rejected with `-20401` |
| `close_review_cycle` | PER-05, PER-06 | Open/other cycle closed; nonexistent cycle behavior |
| `create_review` | PER-07, PER-08 | Review row created; employee notification queued |
| `submit_self_assessment` | PER-09, PER-10 | Valid status transition to manager review; invalid status rejected with `-20402`; reviewer notified |
| `submit_manager_review` | PER-11 through PER-14 | Ratings at each label boundary; out-of-range rating rejected with `-20403`; review completed; employee notified |
| `acknowledge_review` | PER-15, PER-16 | Completed review acknowledged; non-completed review unchanged |
| `add_goal` | PER-17, PER-18 | Goal inserted with defaults; null/optional fields handled |
| `update_goal_progress` | PER-19, PER-20, PER-21 | 0% keeps status; partial progress becomes in-progress; 100% becomes completed |
| `get_team_reviews` | PER-22, PER-23 | Manager sees correct review set; no results case |
| `get_rating_distribution` | PER-24, PER-25 | Percentages and ordering correct; department filter works |
| `generate_reviews_for_cycle` | PER-26, PER-27 | Creates reviews for active employees with managers; duplicate rerun swallows `DUP_VAL_ON_INDEX` and remains idempotent |

### 6.10 PKG_REPORTING

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `headcount_report` | REP-01, REP-02, REP-03 | Correct headcount and demographics; dept filter; location filter |
| `compensation_summary` | REP-04, REP-05 | Grade min/max/avg/median/compa-ratio correct; grade/dept filters |
| `turnover_report` | REP-06, REP-07 | Turnover percentage and voluntary/involuntary counts correct; zero-denominator protection |
| `new_hires_report` | REP-08, REP-09 | Date-range results and manager/salary joins correct; dept filter |
| `leave_utilization_report` | REP-10, REP-11 | Utilization metrics correct; remaining formula aligned with code |
| `payroll_summary_report` | REP-12, REP-13 | Department totals match payroll details; error rows excluded |
| `eeo_compliance_report` | REP-14, REP-15 | Category/gender counts correct as-of date |
| `refresh_reporting_tables` | REP-16, REP-17 | Info log emitted; placeholder behavior documented as non-refreshing legacy stub |

### 6.11 PKG_INTEGRATION

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `generate_gl_journal` | INT-01, INT-02, INT-03 | Flat file created with header/detail/trailer; debit/credit direction by element type; file closed and error logged on failure |
| `export_benefits_feed` | INT-04, INT-05 | Fixed-width output format correct; dependent rows included and ordered |
| `import_time_attendance` | INT-06, INT-07, INT-08 | Comment lines skipped; import count increments; bad line logs error; end-of-file handled cleanly |
| `sync_org_structure` | INT-09 | Placeholder info log behavior |
| `get_integration_status` | INT-10, INT-11 | Reads configured parameter; missing parameter returns null |

---

## 7. Trigger Coverage Catalog

| Trigger | Coverage IDs | What to verify |
|---|---|---|
| `TRG_EMP_BEFORE_INSERT` | TRG-01 through TRG-04 | Audit defaults set; default flags/status set; hire date > 180 days rejected with `-20501`; active email uniqueness rejected with `-20502` |
| `TRG_EMP_BEFORE_UPDATE` | TRG-05 through TRG-08 | Modified columns set; terminated -> active blocked with `-20503`; status change history logged; dept/job change history logged |
| `TRG_EMP_INSTEAD_OF_DELETE` | TRG-09 | Direct delete blocked with `-20504`; Forms workaround documented |
| `TRG_SALARY_AUDIT` | TRG-10 through TRG-12 | Insert/update/delete all call `PKG_AUDIT.log_action` with expected JSON payload shape |
| `TRG_LEAVE_REQUEST_AUDIT` | TRG-13, TRG-14 | Status update creates audit row; non-status update does not fire |
| `TRG_DEPARTMENT_AUDIT` | TRG-15 through TRG-17 | Insert/update/delete all audited with expected action code |

---

## 8. View Coverage Catalog

| View | Coverage IDs | What to verify |
|---|---|---|
| `VW_ACTIVE_EMPLOYEES` | VW-01 through VW-03 | Only active employees with active salary; manager/location joins; tenure/current salary values |
| `VW_ORG_HIERARCHY` | VW-04, VW-05 | Rooting and `CONNECT BY` path correctness; large hierarchy performance risk documented |
| `VW_EMPLOYEE_COMPENSATION` | VW-06, VW-07 | Compa-ratio and salary metadata correctness |
| `VW_LEAVE_SUMMARY` | VW-08, VW-09 | Current-year rows only; available formula excludes `PENDING` in view while table virtual column includes it—document/report drift |
| `VW_PAYROLL_LATEST` | VW-10, VW-11 | Latest approved run only; net/gross/tax aggregation |
| `VW_PENDING_APPROVALS` | VW-12, VW-13 | Union of leave + performance pending items; field mapping consistent across both branches |

---

## 9. PLL and Forms Coverage Catalog

### 9.1 HRMS_COMMON_LIB.pll

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `handle_error` | PLL-01, PLL-02 | Database log attempt made; recursive logging failure suppressed; double `MESSAGE` behavior; raises `FORM_TRIGGER_FAILURE` |
| `toolbar_save` | PLL-03 | `COMMIT_FORM` persists changes |
| `toolbar_clear` | PLL-04 | `CLEAR_FORM(ASK_COMMIT)` behavior |
| `toolbar_query` | PLL-05, PLL-06 | Normal mode enters query; enter-query mode executes query |
| `toolbar_first/prev/next/last` | PLL-07 through PLL-10 | Navigation commands move current record correctly |
| `toolbar_insert` | PLL-11 | `CREATE_RECORD` behavior |
| `toolbar_delete` | PLL-12 | `DELETE_RECORD` attempts delete and surfaces trigger failure for EMPLOYEES |
| `toolbar_exit` | PLL-13 | Exit with commit prompt |
| `format_date` / `format_datetime` | PLL-14, PLL-15 | Output format strings |
| `get_current_user` | PLL-16 | Global user override vs DB user fallback |
| `get_session_id` | PLL-17, PLL-18 | Numeric global value; `VALUE_ERROR` returns null |
| `check_session` | PLL-19, PLL-20 | Missing session blocks form; expired session blocks form |
| `refresh_lov` | PLL-21, PLL-22 | Existing record group repopulated; missing group ignored |

### 9.2 HRMS_VALIDATION_LIB.pll

| Routine | Coverage IDs | What to verify |
|---|---|---|
| `validate_email` | VDR-01 through VDR-03 | Null accepted; basic valid email accepted; valid subdomain email rejected (document drift bug) |
| `validate_phone` | VDR-04, VDR-05 | 10/11-digit phones accepted; invalid length rejected |
| `validate_ssn` | VDR-06, VDR-07 | Valid SSN accepted; zero-group invalid rejected |
| `validate_date_not_future` | VDR-08, VDR-09 | Today valid; future date invalid |
| `validate_salary_range` | VDR-10 through VDR-12 | In-range null message; below/above range messages; invalid grade message |

### 9.3 Forms workflow suites

| Form | Coverage IDs | What to verify |
|---|---|---|
| `HRMS_LOGIN` | FRM-01 through FRM-04 | Valid login; invalid login; expired session re-entry; password conceal/display behavior |
| `HRMS_MENU` | FRM-05, FRM-06 | Role-based navigation using `PKG_SECURITY.has_permission`; denied menu item flow |
| `HRMS_EMPLOYEE` | FRM-07 through FRM-12 | Create/update/transfer/terminate workflow; LOV refresh; delete workaround; post-query display items |
| `HRMS_PAYROLL` | FRM-13 through FRM-16 | Run creation, calculation, approval, pay register generation |
| `HRMS_LEAVE` | FRM-17 through FRM-20 | Submit/approve/reject/cancel leave; half-day behavior |
| `HRMS_PERFORMANCE` | FRM-21 through FRM-24 | Review cycle creation, self-assessment, manager review, acknowledgment |

---

## 10. Known-Defect Regression Suite

These tests must remain in the suite even after modernization, because they define either legacy behavior to preserve temporarily or behavior to deliberately change.

| Defect / risk | Regression IDs | Expected current legacy result |
|---|---|---|
| MD5 password hashing | REG-01 | Same password => same hash; no salt |
| No account lockout | REG-02 | Unlimited failed login attempts remain possible |
| Hard-coded encryption key | REG-03 | Same deployment key decrypts all SSNs |
| Employee number `MAX()+1` race | REG-04 | Concurrent create can produce duplicate-number conflict |
| Payroll partial commit every 50 employees | REG-05 | Failed run may leave committed subset of employees |
| Search SQL injection risk | REG-06 | Concatenated dynamic SQL path accepts malicious payload input |
| Half-day overlap bug | REG-07 | Overlap logic misclassifies certain half-day requests |
| Carryover double-expiry | REG-08 | Same-day rerun subtracts carryover twice |
| Observed holiday bug | REG-09 | Only exact holiday date excluded |
| Validation drift: subdomain email | REG-10 | PLL rejects value that server package accepts |
| Reporting/view drift on available leave | REG-11 | `VW_LEAVE_SUMMARY` formula differs from balance virtual column/runtime formula |
| Org chart / hierarchy performance | REG-12 | Deep hierarchy degrades or times out |

For modernization, each regression must be classified as one of:

- **Preserve initially for parity**
- **Preserve output, fix implementation**
- **Intentionally change behavior and document break from legacy**

---

## 11. Concurrency, Transaction, and Batch Tests

These are mandatory for full coverage because several defects are timing-related.

### 11.1 Concurrency suite

- **CC-01**: Two sessions call `PKG_EMPLOYEE.generate_emp_number` concurrently.
- **CC-02**: Two sessions create employees concurrently and one hits duplicate employee number / unique constraint.
- **CC-03**: Payroll run processing interrupted after first 50 employees to confirm partial commit behavior.
- **CC-04**: Simultaneous leave submissions for same employee overlapping same dates.
- **CC-05**: Notification queue processed concurrently by two workers to inspect duplicate-send risk.

### 11.2 Autonomous transaction suite

- **TX-01**: Caller raises exception after `PKG_COMMON.log_error`; log row still exists.
- **TX-02**: Caller rolls back after `PKG_AUDIT.log_action`; audit row still exists.
- **TX-03**: Business operation rolls back after `PKG_NOTIFICATION.send_notification`; queued notification remains because notification package commits autonomously.

### 11.3 Rerun/idempotency suite

- **ID-01**: `initialize_balances` rerun does not duplicate rows.
- **ID-02**: `generate_reviews_for_cycle` rerun tolerates duplicates.
- **ID-03**: `expire_carryover` rerun shows defect.
- **ID-04**: `retry_failed` rerun does not reset rows above retry threshold.
- **ID-05**: `create_pay_periods` rerun for same year/frequency handling.

---

## 12. Reporting and Data Reconciliation Checks

In addition to routine-level assertions, perform reconciliation queries:

1. `PAYROLL_DETAILS` sums reconcile to `PAYROLL_RUNS` totals.
2. `LEAVE_BALANCES.USED` and `PENDING` reconcile to `LEAVE_REQUESTS` statuses.
3. `EMPLOYEE_HISTORY` rows reconcile to employee status/dept/job changes from package calls and triggers.
4. `AUDIT_LOG` entries reconcile to salary, leave, department, employee, and payroll actions.
5. `NOTIFICATION_QUEUE` rows reconcile to workflow events (review creation, leave approval, termination, payroll alerts if added).
6. View outputs reconcile to underlying base-table queries for the same filters.

---

## 13. Recommended Scenario Execution Order

Run in this order to maximize reuse of saved IDs and reduce fixture churn:

1. `security-auth.yaml`
2. `common-utilities.yaml`
3. `validation-rules.yaml`
4. `employee-crud.yaml`
5. `employee-hierarchy.yaml`
6. `employee-rehire.yaml`
7. `leave-workflow.yaml`
8. `leave-overlap-halfday.yaml`
9. `leave-accrual-carryover.yaml`
10. `payroll-periods.yaml`
11. `payroll-calculation.yaml`
12. `payroll-tax-boundaries.yaml`
13. `performance-cycle.yaml`
14. `performance-goals.yaml`
15. `reporting-outputs.yaml`
16. `integration-file-outputs.yaml`
17. `triggers-and-side-effects.yaml`
18. `views-regression.yaml`
19. `forms-validation-drift.yaml`
20. `forms-navigation-and-toolbar.yaml`

---

## 14. Exit Criteria

The legacy estate is considered fully covered when all of the following are true:

1. Every package routine in Section 6 has at least one implemented automated test and all listed edge cases.
2. Every trigger, view, PLL routine, and form workflow in Sections 7-9 is covered.
3. Every regression in Section 10 is reproducible or explicitly disproven with evidence.
4. Every concurrency/transaction/idempotency case in Section 11 has been executed.
5. Golden legacy outputs have been captured in the modernization harness for all scenario families in Section 5.2.
6. Coverage evidence exists as:
   - SQL assertions / result sets
   - YAML scenarios and result JSON files
   - Forms execution notes/screenshots for UI-only behaviors
   - Reconciliation query outputs

---

## 15. Immediate Implementation Priorities

If this plan is implemented incrementally, start with these highest-value suites first:

1. `security-auth.yaml` expansion
2. `employee-crud.yaml` expansion
3. `payroll-calculation.yaml` expansion
4. `leave-workflow.yaml` expansion
5. `employee-search-injection.yaml`
6. `leave-overlap-halfday.yaml`
7. `leave-accrual-carryover.yaml`
8. `triggers-and-side-effects.yaml`
9. `views-regression.yaml`
10. `forms-validation-drift.yaml`

These ten suites cover the largest modernization risk surface first: security, employee lifecycle, payroll correctness, leave correctness, side effects, and known legacy defects.
