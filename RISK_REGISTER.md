# HRMS Migration Risk Register

## Overview

This document identifies the top 10 Forms-specific migration risks for the HRMS Oracle Forms/PL/SQL application, based on detailed analysis of all 6 Forms modules, 11 PL/SQL packages, 2 PLL libraries, 30 database tables, and documented technical debt. Each risk is assessed for likelihood, impact, and includes concrete mitigation strategies grounded in the codebase.

---

## Risk Scoring Matrix

| Score | Likelihood | Impact |
|-------|-----------|--------|
| 5 | Almost certain (>90%) | Catastrophic - system down, data loss, financial error |
| 4 | Likely (60-90%) | Major - significant functionality loss, compliance violation |
| 3 | Possible (30-60%) | Moderate - degraded functionality, workaround available |
| 2 | Unlikely (10-30%) | Minor - cosmetic issues, minor inconvenience |
| 1 | Rare (<10%) | Negligible - no meaningful user impact |

**Risk Score = Likelihood x Impact** (max 25)

---

## Top 10 Migration Risks

### RISK-01: Circular Dependency Between PKG_EMPLOYEE and PKG_PAYROLL

| Attribute | Value |
|-----------|-------|
| **Category** | Architecture |
| **Likelihood** | 5 (Almost certain) |
| **Impact** | 4 (Major) |
| **Risk Score** | **20** |
| **Affected Components** | PKG_EMPLOYEE (967 lines), PKG_PAYROLL (898 lines) |

**Description:**
`PKG_EMPLOYEE` calls `PKG_PAYROLL.create_salary_record()` during employee creation (line 275), promotion (line 617), and rehire (line 778). Conversely, `PKG_PAYROLL` depends on `PKG_EMPLOYEE.is_active()` for employee validation during payroll calculations. This mutual dependency means neither package can be migrated independently without breaking the other.

**Evidence from codebase:**
```sql
-- PKG_EMPLOYEE.pkb line 273-281
IF p_base_salary IS NOT NULL THEN
    -- NOTE: Circular dependency - calls PKG_PAYROLL.create_salary_record
    -- which in turn may call PKG_EMPLOYEE.is_active for validation
    PKG_PAYROLL.create_salary_record(
        p_emp_id => v_emp_id, p_effective_date => p_hire_date,
        p_base_salary => p_base_salary, p_change_reason => 'NEW_HIRE', p_user => p_user);
END IF;
```

**Mitigation:**
1. Introduce a `SalaryService` interface/facade that decouples the two packages (see MODULE_ORDERING.md, Wave 5).
2. Migrate Employee read operations first (Wave 2) to avoid triggering the circular path.
3. Use Spring's `@Lazy` injection or event-driven architecture to break the compile-time cycle.
4. Test all lifecycle operations (create, promote, rehire) thoroughly after decoupling.

**Owner:** Lead Architect
**Status:** Open

---

### RISK-02: Business Logic Split Between Forms Triggers, PLL Libraries, and PL/SQL Packages

| Attribute | Value |
|-----------|-------|
| **Category** | Business Logic |
| **Likelihood** | 5 (Almost certain) |
| **Impact** | 4 (Major) |
| **Risk Score** | **20** |
| **Affected Components** | All 6 Forms XML exports, HRMS_COMMON_LIB.pll, HRMS_VALIDATION_LIB.pll, PKG_VALIDATION |

**Description:**
Business rules are implemented in three separate layers with no single source of truth:
- **Forms triggers** (e.g., WHEN-VALIDATE-ITEM in HRMS_EMPLOYEE.xml checks hire date <= SYSDATE+90 at line 383)
- **PLL libraries** (e.g., HRMS_VALIDATION_LIB.validate_email has a known bug rejecting valid subdomains)
- **PL/SQL packages** (e.g., PKG_VALIDATION.validate_email_format uses REGEXP_LIKE, a different implementation)

During migration, any logic that exists only in Forms triggers will be lost if not explicitly identified and ported.

**Evidence from codebase:**
```sql
-- HRMS_EMPLOYEE.xml line 382-386 (Forms trigger - hire date validation)
ELSIF v_item = 'EMPLOYEE.HIRE_DATE' THEN
    IF :EMPLOYEE.HIRE_DATE > SYSDATE + 90 THEN
        MESSAGE('Hire date cannot be more than 90 days in the future');
        RAISE FORM_TRIGGER_FAILURE;
    END IF;

-- HRMS_VALIDATION_LIB.pll line 39 (BUG comment)
-- BUG: Only checks for one dot after @, rejects valid subdomains

-- PKG_COMMON.pkb line 267 (different email validation)
RETURN REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
```

**Mitigation:**
1. Create a comprehensive validation rule inventory by auditing every Forms trigger across all 6 XML exports.
2. Compare each Forms-level validation against its PKG_VALIDATION and PLL counterpart; document discrepancies.
3. Establish a single validation layer in the modern system (e.g., Zod schemas shared between React and Java, or Bean Validation annotations on DTOs).
4. Fix known validation bugs during migration (email subdomain rejection, hire date check).

**Owner:** Business Analyst + Lead Developer
**Status:** Open

---

### RISK-03: Hard-Coded Tax Brackets and Payroll Constants

| Attribute | Value |
|-----------|-------|
| **Category** | Compliance / Financial |
| **Likelihood** | 4 (Likely) |
| **Impact** | 5 (Catastrophic) |
| **Risk Score** | **20** |
| **Affected Components** | PKG_PAYROLL.pkb (lines 7-14) |

**Description:**
Federal tax calculation parameters are hard-coded as PL/SQL package constants, including Social Security wage base ($168,600), standard deductions ($14,600 single / $29,200 married), per-allowance amount ($4,300), and FICA/Medicare rates. These values are specific to tax year 2024 and must be updated annually. If the migration carries over hard-coded values instead of making them configurable, the system will produce incorrect tax calculations after the current tax year.

**Evidence from codebase:**
```sql
-- PKG_PAYROLL.pkb lines 7-14
c_ss_wage_base_2024   CONSTANT NUMBER := 168600;   -- Social Security wage base
c_ss_rate             CONSTANT NUMBER := 0.062;     -- 6.2% employee share
c_medicare_rate       CONSTANT NUMBER := 0.0145;    -- 1.45% employee share
c_medicare_addl_rate  CONSTANT NUMBER := 0.009;     -- Additional Medicare tax
c_medicare_addl_threshold CONSTANT NUMBER := 200000;
c_standard_deduction_single CONSTANT NUMBER := 14600;
c_standard_deduction_married CONSTANT NUMBER := 29200;
c_allowance_amount    CONSTANT NUMBER := 4300;
```

**Mitigation:**
1. Extract all tax constants into the `TAX_BRACKETS` table (which already exists but is partially used).
2. Build an admin UI for annual tax bracket updates.
3. Implement tax year versioning so multiple years' brackets coexist.
4. Add automated alerts when a new tax year has no brackets configured.
5. During dual-run validation (Wave 6.8), verify tax calculations match for at least 2 pay periods.

**Owner:** Payroll SME + Lead Developer
**Status:** Open

---

### RISK-04: Oracle Forms GLOBAL Variables and Session State Loss

| Attribute | Value |
|-----------|-------|
| **Category** | Architecture / Security |
| **Likelihood** | 4 (Likely) |
| **Impact** | 4 (Major) |
| **Risk Score** | **16** |
| **Affected Components** | HRMS_LOGIN.xml, HRMS_MENU.xml, all Forms (via HRMS_COMMON_LIB) |

**Description:**
The legacy system stores critical session state in Oracle Forms `GLOBAL` variables: `:GLOBAL.session_id`, `:GLOBAL.current_user`, `:GLOBAL.current_emp_id`. These are set at login (HRMS_LOGIN.xml line 82-90) and propagated to all open forms via the `SESSION` parameter in `OPEN_FORM`. Additionally, `PKG_EMPLOYEE` stores session context in package-level global variables (`g_current_user`, `g_current_emp_id`, `g_current_dept_id`).

During migration, the web application must replicate this session state management in a stateless HTTP context. Any gap in session propagation could result in unauthorized access or operations attributed to the wrong user.

**Evidence from codebase:**
```sql
-- HRMS_LOGIN.xml lines 82-90
:GLOBAL.session_id := TO_CHAR(v_session_id);
:GLOBAL.current_user := :LOGIN.USERNAME;

SELECT EMP_ID INTO :GLOBAL.current_emp_id
FROM EMPLOYEES
WHERE UPPER(EMAIL) = UPPER(:LOGIN.USERNAME)
AND EMPLOYMENT_STATUS = 'ACTIVE' AND ROWNUM = 1;

-- PKG_EMPLOYEE.pks lines 14-17
g_current_user       VARCHAR2(30);
g_current_emp_id     NUMBER(10);
g_current_dept_id    NUMBER(10);
```

**Mitigation:**
1. Replace GLOBAL variables with JWT token claims (user ID, employee ID, roles).
2. Replace PL/SQL package global variables with Spring Security's `SecurityContext` (thread-safe, request-scoped).
3. Use React Context (`AuthProvider`) for client-side session state.
4. Implement proper session timeout using JWT expiry (not DB server time comparison).
5. Add audit trail that links every operation to the authenticated user from the JWT.

**Owner:** Security Architect
**Status:** Open

---

### RISK-05: Oracle Forms-Specific UI Behaviors Without Direct Web Equivalents

| Attribute | Value |
|-----------|-------|
| **Category** | User Experience |
| **Likelihood** | 4 (Likely) |
| **Impact** | 3 (Moderate) |
| **Risk Score** | **12** |
| **Affected Components** | All Forms modules, HRMS_COMMON_LIB.pll |

**Description:**
Oracle Forms has UI behaviors that do not have direct equivalents in web applications. These include:
- **Master-detail coordination**: Navigating a master record automatically queries detail blocks (CYCLE_REVIEW_REL, REVIEW_GOAL_REL in HRMS_PERFORMANCE.xml).
- **Record-level locking**: `SELECT FOR UPDATE NOWAIT` provides immediate feedback on locked records (used in transfer_employee, terminate_employee, approve_leave_request).
- **Commit/rollback semantics**: `COMMIT_FORM` saves all pending changes across all blocks atomically; web apps typically save one form at a time.
- **MESSAGE/MESSAGE pattern**: Oracle Forms requires calling `MESSAGE()` twice to ensure display on the status bar (HRMS_COMMON_LIB.pll lines 32-35).
- **FORM_TRIGGER_FAILURE**: Raising this exception cancels the current operation and returns focus to the field; web equivalent requires careful UX design.
- **Navigation model**: `GO_BLOCK`, `GO_ITEM`, `FIRST_RECORD`, `NEXT_RECORD` assume a cursor-based navigation not present in web UIs.

**Evidence from codebase:**
```sql
-- HRMS_COMMON_LIB.pll lines 32-35
MESSAGE(p_module || '.' || p_location || ': ' || v_errmsg);
MESSAGE(p_module || '.' || p_location || ': ' || v_errmsg);
-- NOTE: MESSAGE called twice intentionally - Oracle Forms requires
-- two calls to ensure message displays on the status bar
```

**Mitigation:**
1. Map each Forms UI pattern to its web equivalent (see COMPONENT_MAPPING.md Section 6).
2. Replace master-detail auto-query with React Query dependent queries (`enabled: !!masterId`).
3. Replace `SELECT FOR UPDATE` with optimistic locking (`@Version` column + HTTP 409 Conflict response).
4. Replace `COMMIT_FORM` with per-form API calls; use React Query mutation with `onSuccess` callbacks.
5. Replace `MESSAGE` with toast notifications (react-toastify or MUI Snackbar).
6. Replace `FORM_TRIGGER_FAILURE` with form-level error state and field-level error display.
7. Conduct user acceptance testing focused on workflow continuity, not pixel-perfect matching.

**Owner:** UX Designer + Frontend Lead
**Status:** Open

---

### RISK-06: Security Vulnerabilities Requiring Immediate Remediation

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Likelihood** | 3 (Possible) |
| **Impact** | 5 (Catastrophic) |
| **Risk Score** | **15** |
| **Affected Components** | PKG_SECURITY.pkb, PKG_EMPLOYEE.pkb, PKG_INTEGRATION.pks |

**Description:**
The legacy system has multiple critical security vulnerabilities that must be addressed during migration, not carried forward:

1. **MD5 password hashing** (PKG_SECURITY.pkb line 21): MD5 is cryptographically broken. Passwords must be migrated to bcrypt/Argon2.
2. **Hard-coded encryption key** (PKG_SECURITY.pkb line 7): `HR$ystem_3ncrypt10n_K3y_2024!!` is in source code. SSN encryption key must move to a secret manager.
3. **SQL injection** (PKG_EMPLOYEE.pkb lines 466-467): `search_employees` uses string concatenation for dynamic SQL.
4. **Cleartext FTP credentials** (PKG_INTEGRATION): FTP passwords stored in `SYSTEM_PARAMETERS` table.
5. **No account lockout** (PKG_SECURITY.pkb line 28-29): Brute-force attacks are not throttled.
6. **Timing attack** (PKG_SECURITY.pkb line 48-50): Different error paths for invalid user vs. invalid password.
7. **No CAPTCHA or 2FA** (HRMS_LOGIN.xml comment): Login form lacks secondary authentication.

**Evidence from codebase:**
```sql
-- PKG_SECURITY.pkb line 7
c_encryption_key RAW(32) := UTL_RAW.CAST_TO_RAW('HR$ystem_3ncrypt10n_K3y_2024!!');

-- PKG_EMPLOYEE.pkb line 467
v_sql := v_sql || 'AND UPPER(e.LAST_NAME) LIKE UPPER(''' || p_last_name || '%'') ';
```

**Mitigation:**
1. **Wave 1 (immediate):** Implement bcrypt for new auth service; create batch job to rehash passwords on first login.
2. **Wave 1:** Move encryption keys to AWS KMS, HashiCorp Vault, or equivalent secret manager.
3. **Wave 5:** Use JPA Specifications (parameterized queries) for all dynamic search.
4. **Wave 8:** Replace FTP with SFTP + key-based auth or API integration.
5. **Wave 1:** Add account lockout (5 failed attempts -> 15-minute lockout) and rate limiting.
6. **Wave 1:** Implement constant-time comparison for authentication responses.
7. **Wave 1:** Add TOTP-based 2FA option for privileged users.

**Owner:** Security Architect
**Status:** Open - Critical

---

### RISK-07: Data Consistency During Dual-System Coexistence

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity |
| **Likelihood** | 4 (Likely) |
| **Impact** | 4 (Major) |
| **Risk Score** | **16** |
| **Affected Components** | All tables; both Oracle Forms and modern Java/React writing to same DB |

**Description:**
During the strangler fig migration, both the legacy Oracle Forms application and the modern Java/React application will read from and write to the same Oracle database simultaneously. This creates risks of:
- **Trigger bypass**: Database triggers (trg_employees.sql, trg_audit.sql) fire on all DML, but the modern app may implement different audit/validation logic, causing duplicate or inconsistent audit records.
- **Sequence gaps**: Both systems using the same sequences could cause unexpected gaps or conflicts.
- **Transaction isolation**: Legacy Forms uses long transactions with COMMIT_FORM; modern app uses short HTTP request-scoped transactions.
- **Cache invalidation**: If the modern app caches data (e.g., React Query cache), changes made via legacy Forms won't invalidate the cache.

**Mitigation:**
1. Keep both systems writing to the same database during coexistence (shared source of truth).
2. Ensure database triggers remain active and compatible with both systems.
3. Use optimistic locking (`VERSION` column) to detect concurrent modifications.
4. Set appropriate React Query `staleTime` values (short for frequently-changing data like leave balances).
5. Create a reconciliation batch job that compares audit trails from both systems nightly.
6. Add an `APP_SOURCE` column to `AUDIT_LOG` to distinguish legacy vs. modern writes.
7. Test concurrent access scenarios: user edits employee in Forms while another user views in React.

**Owner:** Database Architect
**Status:** Open

---

### RISK-08: Payroll Calculation Errors During Migration

| Attribute | Value |
|-----------|-------|
| **Category** | Financial / Compliance |
| **Likelihood** | 3 (Possible) |
| **Impact** | 5 (Catastrophic) |
| **Risk Score** | **15** |
| **Affected Components** | PKG_PAYROLL.pkb (898 lines), HRMS_PAYROLL.xml |

**Description:**
Payroll processing has zero tolerance for error. The legacy system has several known calculation issues that must be fixed without introducing new ones:
- Row-by-row cursor processing with partial commits every 50 employees (PKG_PAYROLL.pkb line 324): if the batch fails mid-run, some employees are committed and others are not.
- Overtime does not account for holidays.
- YTD accumulation resets incorrectly for mid-year hires.
- Taxable income calculation is simplified (line 437: `v_taxable_income := v_period_gross` without subtracting pretax deductions).

Any discrepancy between legacy and modern payroll calculations, even by $0.01, could trigger legal compliance issues, employee complaints, and tax reporting errors.

**Evidence from codebase:**
```sql
-- PKG_PAYROLL.pkb line 322-326
-- Commit every 50 employees to avoid long transactions
-- ISSUE: Partial commits mean a failure leaves payroll half-calculated
IF MOD(v_emp_count, 50) = 0 THEN
    COMMIT;
END IF;

-- PKG_PAYROLL.pkb line 437
v_taxable_income := v_period_gross; -- Simplified; should subtract pretax deductions
```

**Mitigation:**
1. **Mandatory dual-run validation** for at least 2 full pay periods before cutover.
2. Automated comparison report: calculate difference per employee between legacy and modern results.
3. Threshold: only cut over when 100% of employees have variance < $0.01.
4. Use Spring Batch with chunk-oriented processing and proper transaction management (no partial commits).
5. Document all intentional calculation changes (bug fixes) and get payroll manager sign-off.
6. Keep legacy payroll calculation available as fallback for 3 months after cutover.

**Owner:** Payroll SME + QA Lead
**Status:** Open - Critical

---

### RISK-09: Loss of Oracle Forms Record-Level Locking Semantics

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity / Concurrency |
| **Likelihood** | 3 (Possible) |
| **Impact** | 3 (Moderate) |
| **Risk Score** | **9** |
| **Affected Components** | PKG_EMPLOYEE.pkb (transfer, terminate), PKG_LEAVE.pkb (approve, reject, cancel) |

**Description:**
The legacy system uses `SELECT FOR UPDATE NOWAIT` to implement pessimistic locking on records being edited. This prevents two users from simultaneously modifying the same employee transfer, leave approval, or payroll run. Web applications typically use optimistic locking (version numbers) instead, which changes the user experience: instead of being blocked immediately, the second user gets an error on save.

Specific instances in the codebase:
- `transfer_employee`: `SELECT * INTO v_old_rec FROM EMPLOYEES WHERE EMP_ID = p_emp_id FOR UPDATE NOWAIT` (line 523)
- `terminate_employee`: `SELECT * INTO v_emp FROM EMPLOYEES WHERE EMP_ID = p_emp_id FOR UPDATE` (line 659)
- `approve_leave_request`: `SELECT * INTO v_request FROM LEAVE_REQUESTS WHERE REQUEST_ID = p_request_id FOR UPDATE` (line 222)
- `close_pay_period`: `SELECT STATUS INTO v_status FROM PAY_PERIODS WHERE PERIOD_ID = p_period_id FOR UPDATE` (line 196)

**Mitigation:**
1. Add a `VERSION` column (integer) to critical tables: EMPLOYEES, LEAVE_REQUESTS, PAYROLL_RUNS, PAY_PERIODS.
2. Implement JPA `@Version` annotation for automatic optimistic locking.
3. Return HTTP 409 Conflict when version mismatch is detected; display user-friendly "record modified by another user" message.
4. For critical workflows (payroll approval), consider a "checkout" pattern: mark records as being edited with a timeout.
5. Test concurrent editing scenarios for each critical workflow.

**Owner:** Backend Lead
**Status:** Open

---

### RISK-10: PL/SQL-Specific Patterns Without Direct Java Equivalents

| Attribute | Value |
|-----------|-------|
| **Category** | Technical Debt / Architecture |
| **Likelihood** | 3 (Possible) |
| **Impact** | 3 (Moderate) |
| **Risk Score** | **9** |
| **Affected Components** | All PKG_* bodies, database triggers |

**Description:**
Several PL/SQL patterns used extensively in the codebase require careful translation:

1. **PRAGMA AUTONOMOUS_TRANSACTION**: Used in `PKG_COMMON.log_error()` (line 16) and `PKG_EMPLOYEE.log_history()` (line 155) to commit logging independently of the main transaction. Java equivalent requires separate `@Transactional(propagation = REQUIRES_NEW)` or async event publishing.

2. **REF CURSOR output parameters**: Used in `PKG_EMPLOYEE.search_employees()`, `PKG_LEAVE.get_pending_requests()`, `PKG_REPORTING.*`. These return result sets to Forms. Java equivalent is returning DTOs/collections from service methods.

3. **RAISE_APPLICATION_ERROR**: Used throughout with error codes -20001 to -20999. Each needs mapping to appropriate HTTP status codes and exception types in Java.

4. **Oracle CONNECT BY**: Used in `VW_ORG_HIERARCHY` (line 56) and `PKG_EMPLOYEE.get_org_chart()` (line 834) for hierarchical queries. Needs recursive CTE in standard SQL or application-level tree building.

5. **Virtual columns**: `LEAVE_BALANCES.AVAILABLE` is a `GENERATED ALWAYS AS` virtual column. JPA may not support this natively; needs `@Formula` annotation or application-level calculation.

6. **DBMS_CRYPTO**: Used for SSN encryption (AES-256-CBC). Java equivalent is `javax.crypto.Cipher` with proper key management.

7. **NLS-dependent date formatting**: `TO_CHAR(v_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN')` in business day calculations depends on Oracle NLS settings.

**Mitigation:**
1. Create a pattern translation guide mapping each PL/SQL pattern to its Java equivalent (partially covered in COMPONENT_MAPPING.md).
2. For autonomous transactions: use Spring's `ApplicationEventPublisher` with `@TransactionalEventListener(phase = AFTER_COMMIT)` for non-critical logging; `REQUIRES_NEW` for critical audit.
3. For RAISE_APPLICATION_ERROR: create a custom exception hierarchy (`HrmsException`, `EmployeeNotFoundException`, `InsufficientLeaveBalanceException`) mapped to HTTP status codes.
4. For CONNECT BY: use recursive CTEs (standard SQL) or application-level tree traversal with depth limits.
5. For virtual columns: compute `available` balance in the LeaveBalance entity's getter method or use `@Formula`.
6. For DBMS_CRYPTO: use `java.security` / `javax.crypto` with key from secret manager (not hard-coded).
7. For NLS-dependent dates: use `java.time.DayOfWeek` (locale-independent).

**Owner:** Lead Developer
**Status:** Open

---

## Risk Summary Dashboard

| Rank | ID | Risk | Score | Category | Priority |
|------|-----|------|-------|----------|----------|
| 1 | RISK-01 | Circular dependency (PKG_EMPLOYEE <-> PKG_PAYROLL) | **20** | Architecture | Critical |
| 2 | RISK-02 | Business logic split across 3 layers | **20** | Business Logic | Critical |
| 3 | RISK-03 | Hard-coded tax brackets and payroll constants | **20** | Compliance | Critical |
| 4 | RISK-04 | GLOBAL variable / session state loss | **16** | Security | High |
| 5 | RISK-07 | Data consistency during dual-system coexistence | **16** | Data Integrity | High |
| 6 | RISK-06 | Security vulnerabilities (MD5, SQL injection, etc.) | **15** | Security | Critical |
| 7 | RISK-08 | Payroll calculation errors during migration | **15** | Financial | Critical |
| 8 | RISK-05 | Forms-specific UI behaviors without web equivalents | **12** | UX | Medium |
| 9 | RISK-09 | Loss of record-level locking semantics | **9** | Concurrency | Medium |
| 10 | RISK-10 | PL/SQL patterns without direct Java equivalents | **9** | Technical | Medium |

---

## Risk Heat Map

```
            IMPACT
            1     2     3     4     5
         +-----+-----+-----+-----+-----+
    5    |     |     |     |R01  |     |
         |     |     |     |R02  |     |
L   4    |     |     |     |R04  |R03  |
I        |     |     |     |R07  |     |
K   3    |     |     |R09  |     |R06  |
E        |     |     |R10  |     |R08  |
L   2    |     |     |     |     |     |
I        |     |     |     |     |     |
H   1    |     |     |     |     |     |
O        |     |     |     |     |     |
O        +-----+-----+-----+-----+-----+
D
```

---

## Risk Response Plan Summary

| Timeframe | Risks to Address | Key Actions |
|-----------|-----------------|-------------|
| **Immediate (Wave 0-1)** | RISK-06 (Security) | Implement bcrypt auth, move encryption keys to secret manager, add account lockout |
| **Early (Wave 2-3)** | RISK-02 (Split logic), RISK-04 (Session state) | Audit all Forms triggers for business rules, implement JWT-based auth context |
| **Mid (Wave 5)** | RISK-01 (Circular dep), RISK-09 (Locking) | Introduce facade pattern, add optimistic locking columns |
| **Late (Wave 6)** | RISK-03 (Tax brackets), RISK-08 (Payroll errors) | Extract configurable tax tables, mandatory dual-run validation |
| **Throughout** | RISK-05 (UI behaviors), RISK-07 (Data consistency), RISK-10 (PL/SQL patterns) | Pattern translation guide, reconciliation jobs, UAT per wave |
