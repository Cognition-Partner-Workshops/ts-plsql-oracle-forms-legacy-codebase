# Technical Debt Report

> **HRMS v4.2** — Oracle Forms 12c + Oracle Database 19c
> Security vulnerabilities, race conditions, performance anti-patterns, and validation drift ranked by severity.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Severity Definitions](#2-severity-definitions)
3. [Critical Issues](#3-critical-issues)
4. [High-Severity Issues](#4-high-severity-issues)
5. [Medium-Severity Issues](#5-medium-severity-issues)
6. [Low-Severity Issues](#6-low-severity-issues)
7. [Issue Index by Category](#7-issue-index-by-category)

---

## 1. Executive Summary

| Severity | Count | Categories |
|----------|------:|------------|
| **Critical** | 5 | Security (3), Race Condition (1), Data Integrity (1) |
| **High** | 7 | Security (2), Performance (2), Data Integrity (2), Architecture (1) |
| **Medium** | 8 | Validation (2), Performance (2), Maintainability (2), Data Integrity (1), Integration (1) |
| **Low** | 6 | Maintainability (3), Performance (2), Integration (1) |
| **Total** | **26** | |

**Top risk areas:**
1. **Authentication & encryption** — MD5 hashing, hard-coded keys, and no account lockout expose employee PII (SSNs, bank accounts)
2. **Employee number generation** — Race condition can produce duplicate employee numbers under concurrent load
3. **Payroll calculation** — Hard-coded 2024 tax brackets will silently produce incorrect withholdings in future tax years
4. **Circular dependency** — PKG_EMPLOYEE ↔ PKG_PAYROLL creates compilation fragility and blocks independent testing

---

## 2. Severity Definitions

| Severity | Definition | Response |
|----------|-----------|----------|
| **Critical** | Data loss, security breach, or regulatory violation risk. Can affect production immediately. | Fix before next release |
| **High** | Incorrect calculations, data corruption under specific conditions, or significant operational risk. | Fix within current quarter |
| **Medium** | Logic errors affecting edge cases, performance degradation, or maintainability barriers. | Plan for next sprint cycle |
| **Low** | Code quality, minor inefficiencies, or cosmetic issues. | Address during normal refactoring |

---

## 3. Critical Issues

### CRIT-01: MD5 Password Hashing

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `hash_password` function |
| **Impact** | Employee credentials vulnerable to rainbow table attacks; MD5 is cryptographically broken since 2004 |
| **CVSS Equivalent** | 9.1 (Critical) |

**Description:**
`PKG_SECURITY.hash_password` uses `DBMS_CRYPTO.HASH_MD5` to hash user passwords. MD5 produces a 128-bit digest that can be reversed with freely available rainbow tables in seconds. There is no salt applied, meaning identical passwords produce identical hashes, enabling bulk credential analysis.

**Code Reference:**
```sql
-- PKG_SECURITY.pkb
FUNCTION hash_password(p_password IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN RAWTOHEX(DBMS_CRYPTO.HASH(
        UTL_RAW.CAST_TO_RAW(p_password),
        DBMS_CRYPTO.HASH_MD5
    ));
END;
```

**Recommended Fix:**
Replace with `DBMS_CRYPTO.HASH_SH256` at minimum, or preferably use a key-stretching algorithm (bcrypt/PBKDF2) via a Java stored procedure. Add a per-user random salt stored alongside the hash. Implement a phased migration where existing MD5 hashes are re-hashed on next successful login.

---

### CRIT-02: Hard-Coded AES Encryption Key

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — constant `c_encryption_key` |
| **Impact** | Anyone with read access to the package body can decrypt all SSNs in the EMPLOYEES table |

**Description:**
The AES-256 key for SSN encryption is stored as a string constant directly in the package body:

```sql
c_encryption_key CONSTANT VARCHAR2(32) := 'HR$ystem_3ncrypt10n_K3y_2024!!';
```

This key is visible to any DBA, developer with `SELECT ANY DICTIONARY` privilege, or anyone who can read the source files. All encrypted SSNs in `EMPLOYEES.SSN_ENCRYPTED` can be decrypted by calling `PKG_SECURITY.decrypt_ssn` or by using the key directly with `DBMS_CRYPTO`.

**Recommended Fix:**
- Store the encryption key in Oracle Wallet (Oracle Key Vault) or an external secrets manager
- Rotate the key and re-encrypt all SSNs
- Restrict `EXECUTE` privilege on `PKG_SECURITY` to only the application schema
- Consider Oracle Transparent Data Encryption (TDE) as an alternative for at-rest encryption

---

### CRIT-03: No Account Lockout After Failed Login Attempts

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `authenticate` function |
| **Impact** | Unlimited brute-force attempts against any employee account |

**Description:**
The `authenticate` function returns `NULL` on failed login but does not track failed attempt count. There is no lockout mechanism, no progressive delay, and no CAPTCHA or 2FA. Combined with CRIT-01 (MD5 hashing), this makes credential compromise trivial for a determined attacker.

The Forms login form (`HRMS_LOGIN.xml`) displays a generic error message on failure but has no client-side rate limiting either.

**Recommended Fix:**
- Add a `FAILED_LOGIN_COUNT` and `LOCKOUT_UNTIL` column to `EMPLOYEES` (or `USER_SESSIONS`)
- Lock the account after 5 consecutive failures for 15 minutes (configurable via `SYSTEM_PARAMETERS`)
- Log all failed attempts via `PKG_AUDIT.log_login` with the IP address
- Consider implementing 2FA via TOTP

---

### CRIT-04: Employee Number Generation Race Condition

| Attribute | Value |
|-----------|-------|
| **Category** | Race Condition / Data Integrity |
| **Location** | `plsql/packages/PKG_EMPLOYEE.pkb` — `generate_emp_number` function |
| **Impact** | Duplicate employee numbers under concurrent inserts; UNIQUE constraint violation crashes the form |

**Description:**
The `generate_emp_number` function uses `SELECT MAX(EMP_NUMBER) + 1` instead of the available `SEQ_EMP_NUMBER` sequence:

```sql
FUNCTION generate_emp_number RETURN VARCHAR2 IS
    v_next NUMBER;
BEGIN
    SELECT NVL(MAX(TO_NUMBER(SUBSTR(EMP_NUMBER, 5))), 99999) + 1
    INTO v_next
    FROM EMPLOYEES;
    RETURN 'EMP-' || LPAD(v_next, 6, '0');
END;
```

Two concurrent sessions calling `generate_emp_number` before either commits will both receive the same number. The second INSERT will fail with `ORA-00001: unique constraint violated`, presenting an unhelpful error to the user.

**Recommended Fix:**
Replace with `SEQ_EMP_NUMBER.NEXTVAL`:
```sql
RETURN 'EMP-' || LPAD(SEQ_EMP_NUMBER.NEXTVAL, 6, '0');
```

---

### CRIT-05: Cleartext FTP Credentials in SYSTEM_PARAMETERS

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Location** | `plsql/packages/PKG_INTEGRATION.pkb`, `data/seed/01_reference_data.sql` (SYSTEM_PARAMETERS inserts) |
| **Impact** | FTP credentials for integration feeds stored in plaintext in a queryable table |

**Description:**
Integration file transfer credentials (for GL journal, benefits feed) are stored as cleartext values in the `SYSTEM_PARAMETERS` table under category `INTEGRATION`. Any user with `SELECT` on `SYSTEM_PARAMETERS` can read the FTP username and password.

Additionally, the use of FTP (not SFTP/FTPS) means credentials are transmitted in cleartext over the network.

**Recommended Fix:**
- Encrypt credentials at rest using Oracle Wallet or a dedicated secrets table with `DBMS_CRYPTO` encryption
- Replace FTP with SFTP or HTTPS-based file transfer
- Restrict `SELECT` on `SYSTEM_PARAMETERS` rows where `PARAM_CATEGORY = 'INTEGRATION'` using Oracle VPD (Virtual Private Database) or a wrapper function

---

## 4. High-Severity Issues

### HIGH-01: Hard-Coded 2024 Tax Brackets in PKG_PAYROLL

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity / Compliance |
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `calculate_federal_tax`, `calculate_state_tax` |
| **Impact** | Incorrect tax withholdings in any year other than 2024 |

**Description:**
Federal tax brackets are hard-coded as constants in the package body rather than read from the `TAX_BRACKETS` table:

```sql
-- Hard-coded 2024 Single brackets
c_fed_bracket_1  CONSTANT NUMBER := 11600;   -- 10%
c_fed_bracket_2  CONSTANT NUMBER := 47150;   -- 12%
c_fed_bracket_3  CONSTANT NUMBER := 100525;  -- 22%
...
```

Similarly, FICA wage base is hard-coded:
```sql
c_ss_wage_base_2024 CONSTANT NUMBER := 168600;
```

When 2025 (or later) tax rates take effect, payroll runs will use incorrect brackets unless the package is recompiled with new constants.

**Recommended Fix:**
Read tax brackets from the `TAX_BRACKETS` table (which already exists and has a `TAX_YEAR` column). The table was created specifically for this purpose but is bypassed by the hard-coded constants.

---

### HIGH-02: Session Timeout Uses Database Server Time

| Attribute | Value |
|-----------|-------|
| **Category** | Security |
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `is_session_valid` function |
| **Impact** | Session timeout bypassed if Forms client clock and DB server clock are misaligned; sessions may never expire or expire prematurely |

**Description:**
`is_session_valid` compares `SYSDATE` (database server time) against `LAST_ACTIVITY` to determine if the 30-minute timeout has elapsed. However, `LAST_ACTIVITY` is set by the Forms client (via `:GLOBAL` variables and `PKG_EMPLOYEE.set_session_context`), which runs in a different time zone or on a machine with clock drift.

If the client is ahead of the server, sessions appear to expire prematurely. If behind, sessions never time out.

**Recommended Fix:**
Always use `SYSDATE` for both the activity timestamp and the comparison:
```sql
UPDATE USER_SESSIONS
SET LAST_ACTIVITY = SYSDATE
WHERE SESSION_ID = p_session_id;
```
Ensure all timestamps are stored in UTC.

---

### HIGH-03: Carryover Double-Expiry Bug

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity |
| **Location** | `plsql/packages/PKG_LEAVE.pkb` — `expire_carryover` procedure |
| **Impact** | Running the expiry batch twice in the same period subtracts carryover balance twice |

**Description:**
The `expire_carryover` procedure subtracts `CARRYOVER_FROM_PREV` from the balance when the carryover expiry date has passed, but it does not check whether the expiry has already been processed. If the batch job runs twice (e.g., manual re-run after a failure), the carryover amount is deducted again, potentially driving the balance negative.

**Recommended Fix:**
Add a `CARRYOVER_EXPIRED_FLAG` column to `LEAVE_BALANCES` and check it before subtracting:
```sql
UPDATE LEAVE_BALANCES
SET ACCRUED = ACCRUED - CARRYOVER_FROM_PREV,
    CARRYOVER_EXPIRED_FLAG = 'Y'
WHERE CARRYOVER_EXPIRY_DT < SYSDATE
  AND CARRYOVER_FROM_PREV > 0
  AND NVL(CARRYOVER_EXPIRED_FLAG, 'N') = 'N';
```

---

### HIGH-04: Half-Day Leave Overlap Detection Bug

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity |
| **Location** | `plsql/packages/PKG_LEAVE.pkb` — `check_leave_overlap` function |
| **Impact** | Employees can submit overlapping half-day leave requests for the same date |

**Description:**
The overlap check compares date ranges but does not consider the `HALF_DAY_FLAG`. Two half-day requests for the same date (AM and PM) should be allowed, but two half-day requests for the same half of the day should be rejected. The current logic either rejects all same-day requests (too strict) or allows all half-day overlaps (too lenient), depending on how the date comparison is written.

**Recommended Fix:**
Add `HALF_DAY_PERIOD` (AM/PM) to `LEAVE_REQUESTS` and include it in the overlap check:
```sql
AND NOT (lr.HALF_DAY_FLAG = 'Y' AND p_half_day_flag = 'Y'
         AND lr.HALF_DAY_PERIOD != p_half_day_period)
```

---

### HIGH-05: Overtime Calculation Ignores Holidays

| Attribute | Value |
|-----------|-------|
| **Category** | Compliance / Data Integrity |
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `calculate_employee_pay` |
| **Impact** | Holiday overtime pay not calculated at correct premium rate |

**Description:**
The overtime calculation in `calculate_employee_pay` counts hours over 40/week as overtime at 1.5x but does not check whether any of those hours fall on company holidays (which many organizations pay at 2x or 2.5x). The `HOLIDAYS` table exists and is used by `PKG_COMMON.business_days_between` but is not consulted during payroll calculation.

**Recommended Fix:**
Cross-reference `PAYROLL_DETAILS` hours with the `HOLIDAYS` table. Apply configurable holiday premium rates (stored in `SYSTEM_PARAMETERS` or `PAY_ELEMENTS`).

---

### HIGH-06: PKG_EMPLOYEE ↔ PKG_PAYROLL Circular Dependency

| Attribute | Value |
|-----------|-------|
| **Category** | Architecture |
| **Location** | `plsql/packages/PKG_EMPLOYEE.pks` (line 6), `plsql/packages/PKG_PAYROLL.pks` (line 6) |
| **Impact** | Compilation order fragility, `ORA-04068` errors during recompilation, impossible to unit test either package in isolation |

**Description:**
`PKG_EMPLOYEE` calls `PKG_PAYROLL.create_salary_record` (in `create_employee` and `promote_employee`). `PKG_PAYROLL` declares a dependency on `PKG_EMPLOYEE`. This means:

1. Recompiling one package invalidates the other
2. Active sessions may get `ORA-04068: existing state of packages has been discarded` errors
3. Cannot deploy changes to either package independently
4. Cannot write unit tests for either package without the other

**Recommended Fix:**
Extract salary record creation into a new `PKG_SALARY` package, or use an event-driven pattern:
```
PKG_EMPLOYEE → PKG_SALARY.create_salary_record (no reverse dependency)
PKG_PAYROLL → PKG_SALARY.get_salary (no dependency on PKG_EMPLOYEE)
```

---

### HIGH-07: YTD Earnings Reset Bug for Mid-Year Hires

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity / Compliance |
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `get_ytd_earnings` function |
| **Impact** | Incorrect tax withholding for employees hired mid-year |

**Description:**
`get_ytd_earnings` sums all `PAYROLL_DETAILS` for an employee within the current calendar year. For employees hired mid-year who may have had previous employment with YTD earnings that should be considered for FICA wage base calculations, the system has no mechanism to account for prior employer withholdings. The W-4 `EMPLOYEE_TAX_INFO` table does not store prior employer YTD data.

This can result in:
- Over-withholding of Social Security for employees who have already hit the wage base at a prior employer
- Under-withholding if the system assumes zero prior earnings

**Recommended Fix:**
Add `PRIOR_EMPLOYER_YTD_EARNINGS` and `PRIOR_EMPLOYER_SS_WITHHELD` columns to `EMPLOYEE_TAX_INFO`. Include these in the YTD calculations for FICA and Medicare.

---

## 5. Medium-Severity Issues

### MED-01: Client-Side Validation Drift (Email)

| Attribute | Value |
|-----------|-------|
| **Category** | Validation Drift |
| **Location** | `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` — `validate_email` (lines 21-41) vs. `plsql/packages/PKG_VALIDATION.pkb` — `validate_email_format` |
| **Impact** | Valid subdomain emails (e.g., `user@mail.company.com`) rejected client-side but accepted server-side |

**Description:**
The PLL `validate_email` function checks for exactly one dot after the `@` symbol:

```sql
-- HRMS_VALIDATION_LIB.pll.sql
v_domain := SUBSTR(p_email, INSTR(p_email, '@') + 1);
v_dot_pos := INSTR(v_domain, '.');
-- Only checks for ONE dot after @
IF v_dot_pos = 0 OR v_dot_pos = 1 OR v_dot_pos = LENGTH(v_domain) THEN
    RETURN FALSE;
END IF;
```

This rejects valid emails like `user@mail.company.com` (which has two dots after @). The server-side `PKG_VALIDATION.validate_email_format` uses `REGEXP_LIKE` which correctly accepts these addresses.

Users see a form-level validation error for valid emails. If they bypass the form (e.g., via SQL*Plus), the record saves successfully.

**Recommended Fix:**
Update `HRMS_VALIDATION_LIB.validate_email` to match the server-side regex or delegate validation entirely to the server by calling `PKG_VALIDATION.validate_email_format` from the form trigger.

---

### MED-02: Salary Validation Comment/Code Mismatch

| Attribute | Value |
|-----------|-------|
| **Category** | Validation Drift / Maintainability |
| **Location** | `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` — `validate_salary_range` (lines 108-135) |
| **Impact** | Misleading code comments; actual behavior queries DB on every keystroke instead of using cached values |

**Description:**
The function's header comment states it uses "hard-coded cache" for performance, but the actual code executes a `SELECT FROM JOB_GRADES` query on every call. This creates:

1. **False documentation** — developers may assume the function is fast and safe to call frequently
2. **Performance risk** — DB round-trip on every `WHEN-VALIDATE-ITEM` event
3. **Tight schema coupling** — PLL code directly queries a table instead of calling a package function

**Recommended Fix:**
Either implement the described caching using PL/SQL table variables, or correct the comment to match the actual behavior. Ideally, route the check through `PKG_VALIDATION.validate_salary` on the server side.

---

### MED-03: Denormalized Reporting Tables Stale During Business Hours

| Attribute | Value |
|-----------|-------|
| **Category** | Performance / Data Accuracy |
| **Location** | `plsql/packages/PKG_REPORTING.pkb` — `refresh_reporting_tables` |
| **Impact** | Reports accessed during the day show data as of last night's refresh |

**Description:**
`refresh_reporting_tables` is a nightly batch job that truncates and rebuilds the `RPT_*` denormalized reporting tables. During business hours, these tables contain stale data. Reports that use these tables (headcount, turnover, etc.) show yesterday's numbers.

The procedure body is currently a placeholder:
```sql
PROCEDURE refresh_reporting_tables IS
BEGIN
    -- TODO: Implement refresh logic
    -- Truncate and repopulate RPT_* tables
    NULL;
END;
```

This means the refresh is not even implemented — the RPT_* tables (if they exist) are never updated.

**Recommended Fix:**
- Implement the refresh logic
- Consider materialized views with `REFRESH ON COMMIT` or `REFRESH FAST` for near-real-time reporting
- At minimum, add a `LAST_REFRESHED` timestamp visible to report users

---

### MED-04: CONNECT BY Org Hierarchy Performance

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Location** | `schema/views/hrms_views.sql` — `VW_ORG_HIERARCHY` |
| **Impact** | Full table scan with recursive `CONNECT BY` becomes expensive above ~500 employees |

**Description:**
`VW_ORG_HIERARCHY` uses `CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID` with `SYS_CONNECT_BY_PATH`. This performs a recursive self-join on the `EMPLOYEES` table. For a small dataset (25 seed employees), this is instant. As the employee count grows, the cost increases exponentially because:

1. Each level of the hierarchy multiplies the rows processed
2. `SYS_CONNECT_BY_PATH` concatenates strings at every level
3. No index hint or `NOCYCLE` clause is specified (infinite loop risk if a manager reports to their own subordinate)

**Recommended Fix:**
- Add `NOCYCLE` to prevent infinite loops: `CONNECT BY NOCYCLE PRIOR EMP_ID = MANAGER_EMP_ID`
- Add an index on `MANAGER_EMP_ID` (if not already present)
- Consider materializing the hierarchy into an adjacency-list table refreshed on org changes

---

### MED-05: TRG_EMP_INSTEAD_OF_DELETE Behavioral Conflict with Forms

| Attribute | Value |
|-----------|-------|
| **Category** | Data Integrity / UX |
| **Location** | `plsql/triggers/trg_employees.sql` — `TRG_EMP_INSTEAD_OF_DELETE`, `forms/libraries/HRMS_COMMON_LIB.pll.sql` — `toolbar_delete` |
| **Impact** | Forms DELETE_RECORD shows success but record persists, confusing users |

**Description:**
`TRG_EMP_INSTEAD_OF_DELETE` converts a `DELETE` on `VW_ACTIVE_EMPLOYEES` into an `UPDATE` that sets `ACTIVE_FLAG='N'` and `EMPLOYMENT_STATUS='TERMINATED'`. The Forms `toolbar_delete` procedure calls `DELETE_RECORD`, which succeeds at the database level (the trigger fires without raising an exception), but the record still exists in the view (now filtered out by `ACTIVE_FLAG = 'Y'`).

From the user's perspective, they click Delete, see no error, but the record may still appear until the form is re-queried.

**Recommended Fix:**
After the delete trigger fires, the form should explicitly re-query the block or call `CLEAR_RECORD` to remove the row from the screen. Alternatively, replace the delete operation with a dedicated "Terminate Employee" button that calls `PKG_EMPLOYEE.terminate_employee` directly.

---

### MED-06: Hard-Coded SMTP Configuration

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability / Integration |
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` — constants `c_smtp_host`, `c_smtp_port`, `c_from_address` |
| **Impact** | SMTP server change requires package recompilation; no failover |

**Description:**
SMTP connection parameters are declared as package constants:
```sql
c_smtp_host  CONSTANT VARCHAR2(50) := 'smtp.hrms-internal.com';
c_smtp_port  CONSTANT NUMBER := 25;
c_from_address CONSTANT VARCHAR2(100) := 'noreply@hrms.example.com';
```

Changing the mail server requires editing the package body, recompiling, and invalidating all dependent sessions.

**Recommended Fix:**
Move SMTP configuration to `SYSTEM_PARAMETERS` and read via `PKG_COMMON.get_param` at send time. Add connection timeout and retry logic.

---

### MED-07: Business Logic Duplication Across Layers

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability |
| **Location** | Multiple: Forms triggers, PLL libraries, DB triggers, PL/SQL packages |
| **Impact** | Changes to business rules must be replicated in 3-4 places; drift risk is high |

**Description:**
The same business rules are implemented in multiple locations:

| Rule | Forms Trigger | PLL Library | DB Trigger | PL/SQL Package |
|------|:---:|:---:|:---:|:---:|
| Email validation | ✓ (WHEN-VALIDATE-ITEM) | ✓ (HRMS_VALIDATION_LIB) | — | ✓ (PKG_VALIDATION) |
| Salary range check | — | ✓ (HRMS_VALIDATION_LIB) | — | ✓ (PKG_VALIDATION) |
| Audit column setting | ✓ (PRE-INSERT/PRE-UPDATE) | — | ✓ (TRG_EMP_BEFORE_INSERT/UPDATE) | — |
| Employee number generation | ✓ (PRE-INSERT) | — | ✓ (TRG_EMP_BEFORE_INSERT) | ✓ (PKG_EMPLOYEE) |
| Soft delete | ✓ (toolbar_delete) | — | ✓ (TRG_EMP_INSTEAD_OF_DELETE) | ✓ (PKG_EMPLOYEE.terminate) |

**Recommended Fix:**
Consolidate all business rules into the PL/SQL package layer. Forms triggers should only call package procedures. Database triggers should handle only concerns that must be enforced regardless of the entry point (audit columns, surrogate keys).

---

### MED-08: Hard-Coded Fiscal Year Start (October 1)

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability |
| **Location** | `plsql/packages/PKG_COMMON.pkb` — `get_fiscal_year`, `get_fiscal_quarter`; `plsql/packages/PKG_REPORTING.pkb` — multiple reports |
| **Impact** | Organizations with different fiscal year starts cannot use the system |

**Description:**
The fiscal year start (October 1) is hard-coded in `PKG_COMMON`:
```sql
FUNCTION get_fiscal_year(p_date IN DATE) RETURN NUMBER IS
BEGIN
    IF EXTRACT(MONTH FROM p_date) >= 10 THEN
        RETURN EXTRACT(YEAR FROM p_date) + 1;
    ELSE
        RETURN EXTRACT(YEAR FROM p_date);
    END IF;
END;
```

Several reporting procedures also assume an October 1 fiscal year start.

**Recommended Fix:**
Store fiscal year start month in `SYSTEM_PARAMETERS` and reference it dynamically.

---

## 6. Low-Severity Issues

### LOW-01: All Sequences Use NOCACHE

| Attribute | Value |
|-----------|-------|
| **Category** | Performance |
| **Location** | `schema/sequences/hrms_sequences.sql` — all 25 sequences |
| **Impact** | Each `NEXTVAL` call requires a disk write to the data dictionary; creates serialization bottleneck under concurrent load |

**Description:**
All 25 sequences are created with `NOCACHE` (the Oracle default when `CACHE` is not specified). This means every call to `sequence.NEXTVAL` requires a disk write to update the sequence dictionary entry. Under concurrent payroll processing or bulk employee imports, this creates I/O contention.

For a 25-employee system this is negligible, but it will become a bottleneck at scale.

**Recommended Fix:**
Add `CACHE 20` (or higher for high-volume sequences like `SEQ_PAYROLL_DETAIL`, `SEQ_AUDIT_LOG`):
```sql
ALTER SEQUENCE SEQ_PAYROLL_DETAIL CACHE 100;
ALTER SEQUENCE SEQ_AUDIT_LOG CACHE 100;
```
Accept that this may create small gaps in sequence numbers (which is acceptable for surrogate keys).

---

### LOW-02: VARCHAR2(4000) Catch-All Columns

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability / Performance |
| **Location** | Various tables — `AUDIT_LOG.OLD_VALUES`, `AUDIT_LOG.NEW_VALUES` (CLOB), `SYSTEM_PARAMETERS.PARAM_VALUE` (VARCHAR2(500)) |
| **Impact** | Inefficient storage allocation; no data size constraints; potential for unexpected data |

**Description:**
Several columns use overly generous data types. While Oracle VARCHAR2 only stores actual data (not the declared maximum), the lack of meaningful size constraints means:
- No early warning when data exceeds expected bounds
- CLOB columns for audit values prevent simple string operations and indexing
- API consumers cannot predict maximum response sizes

**Recommended Fix:**
Review and tighten column sizes to match actual business requirements. Consider JSON format for `OLD_VALUES`/`NEW_VALUES` with schema validation.

---

### LOW-03: No Unit Tests

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability |
| **Location** | Entire codebase |
| **Impact** | No automated verification of business logic; regressions discovered only in production |

**Description:**
The codebase contains zero automated tests. There are no utPLSQL test packages, no SQL*Plus test scripts, and no testing framework of any kind. All testing is presumably manual.

**Recommended Fix:**
Adopt [utPLSQL](https://utplsql.org/) for PL/SQL unit testing. Start with critical paths: `PKG_PAYROLL.calculate_employee_pay`, `PKG_LEAVE.check_leave_overlap`, `PKG_SECURITY.authenticate`.

---

### LOW-04: Dead Code and Placeholder Procedures

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability |
| **Location** | Multiple |
| **Impact** | Misleading API surface; developers may call non-functional code |

**Description:**
Several procedures are stubs or placeholders:

| Procedure | Status |
|-----------|--------|
| `PKG_INTEGRATION.sync_org_structure` | Body contains only `NULL;` |
| `PKG_INTEGRATION.import_time_attendance` | Contains `TODO: actual parsing not implemented` |
| `PKG_REPORTING.refresh_reporting_tables` | Body contains only `NULL;` |

**Recommended Fix:**
Either implement the functionality or remove the procedures from the package specification. If kept as placeholders, raise `RAISE_APPLICATION_ERROR(-20999, 'Not yet implemented')` to prevent silent failure.

---

### LOW-05: Notification HTML Templates as String Constants

| Attribute | Value |
|-----------|-------|
| **Category** | Maintainability |
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` — `process_queue` |
| **Impact** | Any template change requires package recompilation |

**Description:**
Email HTML templates are embedded as PL/SQL string constants within the package body. Modifying a notification template (e.g., adding a company logo, changing wording) requires editing the package body, recompiling, and potentially disrupting active sessions.

**Recommended Fix:**
Store templates in a `NOTIFICATION_TEMPLATES` table or external files. Use a simple token replacement engine (e.g., `REPLACE(template, '{{EMPLOYEE_NAME}}', v_name)`).

---

### LOW-06: No Rate Limiting on Notifications

| Attribute | Value |
|-----------|-------|
| **Category** | Integration / Performance |
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` — `process_queue` |
| **Impact** | Bulk operations (e.g., mass termination) can flood the SMTP server and trigger spam filters |

**Description:**
`process_queue` processes all PENDING notifications in a single loop with no throttling, retry backoff, or batch size limit. A single payroll run for 500 employees generates 500+ notification records, all sent in rapid succession.

**Recommended Fix:**
- Add a configurable `BATCH_SIZE` parameter (e.g., 50 per invocation)
- Implement exponential backoff on SMTP failures
- Add per-recipient rate limiting (e.g., max 10 emails/hour/recipient)

---

## 7. Issue Index by Category

### By Category

| Category | Issues |
|----------|--------|
| **Security** | CRIT-01, CRIT-02, CRIT-03, CRIT-05, HIGH-02 |
| **Data Integrity** | CRIT-04, HIGH-01, HIGH-03, HIGH-04, HIGH-05, HIGH-07, MED-05 |
| **Performance** | MED-03, MED-04, LOW-01, LOW-02 |
| **Validation Drift** | MED-01, MED-02 |
| **Maintainability** | MED-06, MED-07, MED-08, LOW-03, LOW-04, LOW-05 |
| **Architecture** | HIGH-06 |
| **Integration** | LOW-06 |

### By Location

| Source File | Issues |
|------------|--------|
| `PKG_SECURITY.pkb` | CRIT-01, CRIT-02, CRIT-03, HIGH-02 |
| `PKG_EMPLOYEE.pkb` | CRIT-04, HIGH-06 |
| `PKG_PAYROLL.pkb` | HIGH-01, HIGH-05, HIGH-06, HIGH-07 |
| `PKG_LEAVE.pkb` | HIGH-03, HIGH-04 |
| `PKG_INTEGRATION.pkb` | CRIT-05, LOW-04 |
| `PKG_NOTIFICATION.pkb` | MED-06, LOW-05, LOW-06 |
| `PKG_REPORTING.pkb` | MED-03, LOW-04 |
| `PKG_COMMON.pkb` | MED-08 |
| `HRMS_VALIDATION_LIB.pll.sql` | MED-01, MED-02 |
| `trg_employees.sql` | MED-05 |
| `hrms_views.sql` | MED-04 |
| `hrms_sequences.sql` | LOW-01 |
| Multiple files | MED-07, LOW-02, LOW-03 |
