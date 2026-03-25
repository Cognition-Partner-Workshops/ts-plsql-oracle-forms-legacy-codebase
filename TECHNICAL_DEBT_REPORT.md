# Technical Debt Report

> **HRMS Legacy Oracle Forms / PL/SQL Estate**
> Security vulnerabilities, race conditions, performance anti-patterns, and validation drift ranked by severity.

---

## 1. Executive Summary

| Severity | Count | Categories |
|---|---|---|
| **CRITICAL** | 6 | Security vulnerabilities, data integrity risks |
| **HIGH** | 8 | Race conditions, data loss risks, compliance gaps |
| **MEDIUM** | 10 | Performance anti-patterns, maintainability issues |
| **LOW** | 7 | Code quality, minor drift, cosmetic issues |
| **Total** | **31** | |

---

## 2. CRITICAL Severity

### TD-001: MD5 Password Hashing (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `hash_password` function |
| **Description** | Passwords are hashed using MD5 (`DBMS_OBFUSCATION_TOOLKIT.MD5` or `DBMS_CRYPTO.HASH` with `HASH_MD5`). MD5 is cryptographically broken — collisions can be generated in seconds, and rainbow table attacks trivially reverse common passwords. |
| **Impact** | Complete compromise of all user credentials if database is breached. Fails PCI-DSS, SOC 2, and NIST 800-63b requirements. |
| **Recommendation** | Replace with bcrypt, scrypt, or Argon2id with per-user salts. Minimum: SHA-256 with unique salt per password (PBKDF2 with ≥600,000 iterations per OWASP 2024). |

---

### TD-002: Hard-Coded Encryption Key in Source Code (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — constant used for `DBMS_CRYPTO.ENCRYPT`/`DECRYPT` |
| **Description** | The AES encryption key for SSN and bank account encryption is a hard-coded constant in the package body source. Anyone with read access to the PL/SQL source (DBA, developer, version control) can decrypt all sensitive PII. |
| **Impact** | Exposure of Social Security Numbers and bank account numbers for all employees and dependents. Violates HIPAA, PCI-DSS, SOC 2 encryption key management requirements. |
| **Recommendation** | Move encryption key to Oracle Wallet, Oracle Key Vault, or HSM. Implement key rotation. Remove key from version-controlled source. |

---

### TD-003: Cleartext FTP Credentials in SYSTEM_PARAMETERS (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_INTEGRATION.pkb`, `schema/tables/04_performance_tables.sql` (`SYSTEM_PARAMETERS`), `data/seed/01_reference_data.sql` |
| **Description** | FTP server credentials (username, password, host) for external system integration (GL feed, benefits export) are stored as plain text in the `SYSTEM_PARAMETERS` table. Any user with SELECT access to this table can read the credentials. |
| **Impact** | Unauthorized access to external financial systems. Potential for data exfiltration or GL fraud. |
| **Recommendation** | Store credentials in Oracle Wallet or encrypted vault. Use SFTP/FTPS with certificate-based authentication. Restrict `SYSTEM_PARAMETERS` access via VPD or dedicated credentials table with column-level encryption. |

---

### TD-004: No Account Lockout After Failed Login Attempts (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `authenticate` procedure |
| **Description** | Failed login attempts are logged but do not trigger account lockout. There is no maximum attempt threshold, no progressive delay, and no CAPTCHA equivalent. Brute-force attacks against weak passwords are trivially possible. |
| **Impact** | Combined with MD5 hashing (TD-001), this makes credential compromise highly likely under sustained attack. |
| **Recommendation** | Implement account lockout after 5 failed attempts (configurable via `SYSTEM_PARAMETERS`). Add progressive delay (exponential backoff). Log failed attempts with IP and trigger alert on threshold. |

---

### TD-005: SQL Injection in search_employees (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_EMPLOYEE.pkb` — `search_employees` procedure |
| **Description** | Dynamic SQL is constructed via string concatenation of user-provided search parameters. Input is not sanitized or parameterized via bind variables. |
| **Impact** | Attacker with Forms access can execute arbitrary SQL as the `HRMS` schema owner, potentially reading/modifying any data or escalating privileges. |
| **Recommendation** | Refactor to use `DBMS_SQL` with bind variables or `EXECUTE IMMEDIATE ... USING` with bind parameters. Apply `DBMS_ASSERT` for identifiers. |

---

### TD-006: Timing Attack on Password Comparison (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `authenticate` procedure |
| **Description** | Password hash comparison uses standard string equality (`=`), which short-circuits on the first differing byte. This leaks timing information that can be used to determine the hash character by character. |
| **Impact** | Enables offline brute-force optimization. Lower severity in isolation but compounds with MD5 (TD-001) and no lockout (TD-004). |
| **Recommendation** | Use constant-time comparison function (e.g., `DBMS_CRYPTO.MAC` comparison or custom XOR-based equality check). |

---

## 3. HIGH Severity

### TD-007: Race Condition in generate_emp_number (Data Integrity)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_EMPLOYEE.pkb` — `generate_emp_number` function |
| **Description** | Employee number generation uses `SELECT MAX(EMP_NUMBER) + 1 FROM EMPLOYEES` without `SELECT FOR UPDATE` or serialization. Concurrent inserts can generate duplicate employee numbers. The sequence `SEQ_EMP_NUMBER` exists as a fallback but is not the primary mechanism. |
| **Impact** | Duplicate employee numbers under concurrent onboarding (batch hires, multiple HR users). Unique constraint violation errors in production. |
| **Recommendation** | Use `SEQ_EMP_NUMBER.NEXTVAL` as the sole mechanism for employee number generation. Remove the MAX()+1 pattern entirely. |

---

### TD-008: Hard-Coded 2024 Tax Brackets (Compliance)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `calculate_federal_tax`, `calculate_state_tax` |
| **Description** | Federal and state tax brackets are hard-coded as constants in the package body instead of reading from the `TAX_BRACKETS` table that was purpose-built for this data. When tax rates change annually (they always do), the package body must be recompiled and redeployed. |
| **Impact** | Incorrect tax withholding for all employees after 2024. Potential IRS/state penalties and employee W-2 discrepancies. Requires developer intervention for an annual administrative task. |
| **Recommendation** | Refactor tax functions to read from `TAX_BRACKETS` table. Expose admin UI for annual bracket updates. Add validation to flag missing brackets for the current tax year. |

---

### TD-009: Circular Dependency PKG_EMPLOYEE <-> PKG_PAYROLL (Architecture)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_EMPLOYEE.pkb` (calls `PKG_PAYROLL.create_salary_record`), `plsql/packages/PKG_PAYROLL.pkb` (references `PKG_EMPLOYEE` types) |
| **Description** | `PKG_EMPLOYEE.create_employee` calls `PKG_PAYROLL.create_salary_record`, while `PKG_PAYROLL` references `PKG_EMPLOYEE` types and functions. This creates a bidirectional compile-time and runtime dependency. |
| **Impact** | Cannot deploy either package independently. Compilation order is fragile. Prevents clean module extraction for modernization. Makes unit testing impossible without both packages. |
| **Recommendation** | Extract salary record creation into a standalone procedure or trigger. Use event-based decoupling. |

---

### TD-010: Half-Day Leave Overlap Detection Bug (Business Logic)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_LEAVE.pkb` — `check_leave_overlap` |
| **Description** | The overlap detection query does not account for half-day requests (`HALF_DAY_FLAG = 'Y'`). An employee with an approved AM half-day can be blocked from requesting a PM half-day on the same date, or worse, two half-day requests can be approved for the same period. |
| **Impact** | Incorrect leave balance deductions. Employee frustration. Inaccurate attendance records. |
| **Recommendation** | Add `HALF_DAY_PERIOD` to the overlap detection logic. Treat AM and PM as separate slots for the same date. |

---

### TD-011: Carryover Double-Expiry Bug (Business Logic)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_LEAVE.pkb` — `expire_carryover` procedure |
| **Description** | If the `expire_carryover` batch is run twice on the same day (e.g., due to job scheduler retry or manual re-execution), carryover balances are subtracted twice. There is no idempotency check (e.g., "already expired for this date"). |
| **Impact** | Employees lose more leave days than they should. Difficult to detect without manual audit. |
| **Recommendation** | Add idempotency guard: check if expiry was already processed for the given date before subtracting. Add `LAST_EXPIRY_RUN_DATE` to `LEAVE_BALANCES` or use `LEAVE_ACCRUAL_LOG` as a check. |

---

### TD-012: YTD Reset Bug for Mid-Year Hires (Payroll)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `get_ytd_earnings` |
| **Description** | Year-to-date earnings calculation does not account for employees hired mid-year who may have YTD earnings from a previous employer (for tax bracket purposes). The calculation starts from zero regardless of prior employment within the same tax year. |
| **Impact** | Potential under-withholding of taxes for employees who change jobs mid-year. |
| **Recommendation** | Add `PRIOR_YTD_EARNINGS` field to `EMPLOYEE_TAX_INFO`. Include prior earnings in YTD calculations for the first tax year. |

---

### TD-013: Overtime Calculation Ignores Holidays (Payroll)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — overtime calculation section |
| **Description** | Overtime hours calculation does not cross-reference the `HOLIDAYS` table. Hours worked on company holidays are treated as regular overtime (1.5x) instead of holiday overtime (2.0x or 2.5x as configured). |
| **Impact** | Employees underpaid for holiday work. Potential labor law violations (FLSA, state laws). |
| **Recommendation** | Cross-reference `HOLIDAYS` table during overtime calculation. Apply holiday premium rate for hours worked on observed holidays. |

---

### TD-014: DELETE Trigger Mismatch with Forms (Architecture)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/triggers/trg_employees.sql` — `TRG_EMP_INSTEAD_OF_DELETE` |
| **Description** | The trigger raises `RAISE_APPLICATION_ERROR(-20504, ...)` on DELETE, implementing a soft-delete pattern. However, the Oracle Forms `DELETE_RECORD` built-in expects the underlying DELETE to succeed. The documented workaround is to set `ACTIVE_FLAG = 'N'` then `CLEAR_RECORD`, but this is fragile and not enforced. |
| **Impact** | Confusing user experience (delete appears to fail). Workaround must be manually maintained across all forms. New developers may not know about the workaround. |
| **Recommendation** | Replace with a proper INSTEAD OF trigger on a view, or enforce the soft-delete pattern entirely in the Forms layer with `ON-DELETE` trigger. |

---

## 4. MEDIUM Severity

### TD-015: Row-by-Row Payroll Processing (Performance)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_PAYROLL.pkb` — `run_payroll` |
| **Description** | Payroll calculation iterates employee-by-employee using a cursor loop (`FOR emp IN c_active_employees LOOP`). Each iteration executes multiple SELECTs and INSERTs. For 1000 employees with 10 pay elements each, this generates ~11,000 individual SQL statements. |
| **Impact** | Payroll run duration grows linearly. Context switches between PL/SQL and SQL engines dominate execution time. Estimated 10-15 minutes for 1000 employees when BULK COLLECT + FORALL could do it in under 1 minute. |
| **Recommendation** | Refactor to use `BULK COLLECT ... LIMIT 100` with `FORALL` for batch DML. Process pay elements in set-based SQL where possible. |

---

### TD-016: Denormalized Reporting Tables Stale During Business Hours (Performance)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_REPORTING.pkb` — `refresh_reporting_tables` |
| **Description** | Reporting tables are refreshed by a nightly batch job. During business hours, reports reflect yesterday's data. Real-time reporting is not possible. Users see stale headcount, compensation, and turnover numbers. |
| **Impact** | Incorrect business decisions based on stale data. Confusing discrepancies when users see different numbers in operational vs. reporting views. |
| **Recommendation** | Replace batch-refreshed denormalized tables with materialized views using `FAST REFRESH ON COMMIT` or `REFRESH ON DEMAND` with shorter intervals. Alternatively, use the existing database views for real-time queries. |

---

### TD-017: Hard-Coded Fiscal Year Start (Maintainability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_REPORTING.pkb` — multiple report procedures |
| **Description** | Fiscal year start is hard-coded as October 1 in report calculations instead of reading from `SYSTEM_PARAMETERS`. If the organization's fiscal year changes, multiple procedures must be modified. |
| **Impact** | Incorrect fiscal year reporting if fiscal calendar changes. Developer intervention required for configuration change. |
| **Recommendation** | Read fiscal year start from `SYSTEM_PARAMETERS` table (e.g., `PKG_COMMON.get_param('PAYROLL', 'FISCAL_YEAR_START')`). |

---

### TD-018: Hard-Coded SMTP Server in PKG_NOTIFICATION (Maintainability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` — SMTP connection constants |
| **Description** | SMTP server hostname, port, and sender email are hard-coded as package body constants. Server migration or email configuration changes require recompilation. |
| **Impact** | Notification system breaks silently if SMTP server changes. Requires developer deployment for infrastructure change. |
| **Recommendation** | Move to `SYSTEM_PARAMETERS`. Add health check procedure to verify SMTP connectivity. |

---

### TD-019: No Rate Limiting on Notifications (Reliability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` — `process_notification_queue` |
| **Description** | Notification queue processing has no rate limiting. A batch operation (e.g., annual review generation for 500 employees) floods the SMTP server with 500+ emails simultaneously. No throttling, no batch windowing. |
| **Impact** | SMTP server overwhelm. Email delivery delays or failures. Potential blacklisting by email providers. |
| **Recommendation** | Implement configurable rate limiting (e.g., 50 emails/minute). Add batch windowing for bulk operations. Implement retry with exponential backoff. |

---

### TD-020: VW_ORG_HIERARCHY Performance Degradation (Performance)

| Attribute | Detail |
|---|---|
| **Location** | `schema/views/hrms_views.sql` — `VW_ORG_HIERARCHY` |
| **Description** | The org hierarchy view uses `CONNECT BY PRIOR` for hierarchical traversal. This works well for small datasets but degrades exponentially as employee count grows. The code comments warn about degradation above 500 employees. |
| **Impact** | Org chart queries timeout or consume excessive temp tablespace for organizations >500 employees. |
| **Recommendation** | Replace with recursive CTE (`WITH ... AS (SELECT ... UNION ALL)`), materialized path, or nested set model. Cache hierarchy in a flat table refreshed on org changes. |

---

### TD-021: COMMIT Inside Loops in Leave Accrual (Reliability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_LEAVE.pkb` — `run_monthly_accrual` |
| **Description** | The monthly accrual batch commits every 100 employees (`IF MOD(v_count, 100) = 0 THEN COMMIT; END IF;`). If the batch fails at employee #350, employees #1-300 have their accrual committed but #301-350 do not. This creates a partially-processed state that is difficult to recover from. |
| **Impact** | Inconsistent leave balances on batch failure. Manual investigation required to determine which employees were processed. No automatic restart capability. |
| **Recommendation** | Use a single transaction with SAVEPOINT-based recovery, or implement a proper batch framework with checkpoint/restart capability (e.g., record last processed `EMP_ID`). |

---

### TD-022: HTML Email Templates as String Constants (Maintainability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_NOTIFICATION.pkb` |
| **Description** | Email HTML templates are embedded as PL/SQL string constants in the package body. Any template change (branding, layout, content) requires PL/SQL recompilation and database deployment. |
| **Impact** | Business users cannot modify email templates without developer involvement. Risk of PL/SQL syntax errors when editing HTML within string literals. |
| **Recommendation** | Move templates to a `NOTIFICATION_TEMPLATES` table or external file system. Use a simple token replacement engine (`{EMPLOYEE_NAME}`, `{LEAVE_DATES}`, etc.). |

---

### TD-023: UTL_FILE Integration Instead of API (Architecture)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_INTEGRATION.pkb` — all integration procedures |
| **Description** | All external system integration uses `UTL_FILE` to write/read flat files from Oracle Directory objects. Files are then transferred via FTP (credentials in cleartext per TD-003). There is no API-based integration, no message queue, no web service. |
| **Impact** | Integration is batch-only (no real-time). File format changes break integration silently. No acknowledgment/receipt mechanism. Manual FTP monitoring required. |
| **Recommendation** | Replace with REST API calls using `UTL_HTTP` or `APEX_WEB_SERVICE`. Implement message queuing via Oracle AQ. Add acknowledgment tracking. |

---

### TD-024: No Retry Logic for Integration Failures (Reliability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_INTEGRATION.pkb` |
| **Description** | File generation and transfer have no retry mechanism. If `UTL_FILE.FOPEN` fails (directory unavailable, permissions, disk full), the entire integration run fails with no automatic retry. The `import_time_attendance` procedure is entirely a stub (parsing not implemented). |
| **Impact** | Missed GL postings. Benefits feed gaps. Manual intervention required for every failure. |
| **Recommendation** | Implement retry with configurable attempt count and delay. Add integration status tracking table. Implement dead-letter queue for failed transfers. |

---

## 5. LOW Severity

### TD-025: Validation Drift Between Client and Server (Consistency)

| Attribute | Detail |
|---|---|
| **Location** | `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` vs `plsql/packages/PKG_VALIDATION.pkb` |
| **Description** | Client-side validation in `HRMS_VALIDATION_LIB` and server-side validation in `PKG_VALIDATION` implement overlapping but divergent rules. Specifically, `validate_email` in the PLL rejects certain internal subdomains (e.g., `.internal`, `.local`) that the server-side package accepts. Other minor differences exist in phone number format validation and date range boundary checks. |
| **Impact** | Users may be unable to save valid data (client rejects what server accepts) or may bypass client validation and have server reject at save time (confusing error messages). |
| **Recommendation** | Consolidate all validation to server-side `PKG_VALIDATION` and have Forms call these procedures directly via database round-trip. If client-side performance is required, generate client validation from the same rule definitions. |

---

### TD-026: Business Logic Duplication Across Triggers, Packages, and Forms (Maintainability)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/triggers/trg_employees.sql`, `plsql/packages/PKG_EMPLOYEE.pkb`, `forms/xml-exports/HRMS_EMPLOYEE.xml` |
| **Description** | Business rules such as email uniqueness, hire date validation, and audit column population are implemented in multiple places: (1) Forms-level `WHEN-VALIDATE-ITEM` triggers, (2) database `TRG_EMP_BEFORE_INSERT`/`TRG_EMP_BEFORE_UPDATE` triggers, and (3) `PKG_EMPLOYEE` procedures. Rules can diverge silently. |
| **Impact** | Maintenance burden multiplied by 3x for each business rule. Risk of inconsistency when one location is updated but others are not. |
| **Recommendation** | Designate a single authoritative layer for each rule (preferably database level for data integrity, package level for business logic). Remove redundant implementations. |

---

### TD-027: NOCACHE on All Sequences Except SEQ_AUDIT (Performance)

| Attribute | Detail |
|---|---|
| **Location** | `schema/sequences/hrms_sequences.sql` |
| **Description** | All 24 non-audit sequences use `NOCACHE`, which forces a data dictionary update for every `NEXTVAL` call. Only `SEQ_AUDIT` uses `CACHE 100`. |
| **Impact** | Contention on `SYS.SEQ$` table during high-volume operations (batch payroll, bulk accrual). Minimal impact for low-volume sequences. |
| **Recommendation** | Add `CACHE 20` to frequently-used sequences: `SEQ_EMPLOYEE`, `SEQ_SALARY`, `SEQ_PAYROLL_DETAIL`, `SEQ_LEAVE_REQUEST`, `SEQ_PERF_REVIEW`, `SEQ_NOTIFICATION`. Accept minor gaps in sequence numbers. |

---

### TD-028: VARCHAR2(4000) Catch-All Columns (Data Quality)

| Attribute | Detail |
|---|---|
| **Location** | Various tables — `COMMENTS`, `ERROR_MESSAGE`, `NOTES` columns |
| **Description** | Multiple columns use `VARCHAR2(4000)` as a catch-all size regardless of actual expected content. This wastes memory in PGA for SELECT operations and provides no meaningful length constraint. |
| **Impact** | Minor memory overhead. No effective input validation at the database level. |
| **Recommendation** | Apply appropriate size constraints based on actual business requirements. Use CLOB for genuinely large text fields. |

---

### TD-029: Dead Code and Unused Procedures (Maintainability)

| Attribute | Detail |
|---|---|
| **Location** | Various packages |
| **Description** | Several package specifications declare procedures/functions that are not called by any form, trigger, or other package. Without runtime profiling, these cannot be definitively identified, but candidates include utility functions in `PKG_COMMON` and deprecated reporting procedures in `PKG_REPORTING`. |
| **Impact** | Increased code surface area. Confusing for new developers. Must be maintained during schema changes. |
| **Recommendation** | Enable `DBMS_HPROF` profiling in a test environment. Identify uncalled procedures over a full business cycle. Mark deprecated with comments, then remove after verification. |

---

### TD-030: Mixed Naming Conventions (Consistency)

| Attribute | Detail |
|---|---|
| **Location** | Various packages and tables |
| **Description** | Naming conventions are inconsistent: some columns use `_FLAG` suffix (e.g., `ACTIVE_FLAG`), others use `_IND`; procedures mix `get_`/`fetch_`/`retrieve_` prefixes; type names inconsistently use `t_` prefix. Parameters sometimes use `p_` prefix, sometimes not. |
| **Impact** | Reduced code readability. Harder for new developers to predict names. |
| **Recommendation** | Establish and document naming standards. Apply consistently during modernization rather than refactoring in-place. |

---

### TD-031: Session Timeout Uses Database Time (Security)

| Attribute | Detail |
|---|---|
| **Location** | `plsql/packages/PKG_SECURITY.pkb` — `validate_session` |
| **Description** | Session timeout comparison uses `SYSDATE` (database server time) rather than the client's last activity time. If there is a time zone mismatch between the database server and the Forms application server, sessions may expire prematurely or persist too long. |
| **Impact** | Users unexpectedly logged out, or sessions remain active longer than the configured timeout. |
| **Recommendation** | Use a consistent time source. Store `LAST_ACTIVITY_TIME` in `USER_SESSIONS` updated on each request. Compare against the same clock (database `SYSDATE` is acceptable if used consistently). |

---

## 6. Summary by Category

### Security (7 items)

| ID | Severity | Issue |
|---|---|---|
| TD-001 | CRITICAL | MD5 password hashing |
| TD-002 | CRITICAL | Hard-coded encryption key |
| TD-003 | CRITICAL | Cleartext FTP credentials |
| TD-004 | CRITICAL | No account lockout |
| TD-005 | CRITICAL | SQL injection in search_employees |
| TD-006 | CRITICAL | Timing attack on password comparison |
| TD-031 | LOW | Session timeout uses DB time |

### Data Integrity / Race Conditions (3 items)

| ID | Severity | Issue |
|---|---|---|
| TD-007 | HIGH | Race condition in generate_emp_number |
| TD-010 | HIGH | Half-day leave overlap bug |
| TD-011 | HIGH | Carryover double-expiry bug |

### Compliance (3 items)

| ID | Severity | Issue |
|---|---|---|
| TD-008 | HIGH | Hard-coded 2024 tax brackets |
| TD-012 | HIGH | YTD reset bug for mid-year hires |
| TD-013 | HIGH | Overtime ignores holidays |

### Architecture / Design (4 items)

| ID | Severity | Issue |
|---|---|---|
| TD-009 | HIGH | Circular dependency PKG_EMPLOYEE <-> PKG_PAYROLL |
| TD-014 | HIGH | DELETE trigger mismatch with Forms |
| TD-023 | MEDIUM | UTL_FILE integration instead of API |
| TD-026 | LOW | Business logic duplication (triggers/packages/forms) |

### Performance (4 items)

| ID | Severity | Issue |
|---|---|---|
| TD-015 | MEDIUM | Row-by-row payroll processing |
| TD-016 | MEDIUM | Stale denormalized reporting tables |
| TD-020 | MEDIUM | VW_ORG_HIERARCHY CONNECT BY degradation |
| TD-027 | LOW | NOCACHE on all sequences |

### Reliability (3 items)

| ID | Severity | Issue |
|---|---|---|
| TD-019 | MEDIUM | No notification rate limiting |
| TD-021 | MEDIUM | COMMIT inside loops in accrual |
| TD-024 | MEDIUM | No retry logic for integration |

### Maintainability (5 items)

| ID | Severity | Issue |
|---|---|---|
| TD-017 | MEDIUM | Hard-coded fiscal year start |
| TD-018 | MEDIUM | Hard-coded SMTP server |
| TD-022 | MEDIUM | HTML templates as string constants |
| TD-029 | LOW | Dead code / unused procedures |
| TD-030 | LOW | Mixed naming conventions |

### Data Quality / Consistency (2 items)

| ID | Severity | Issue |
|---|---|---|
| TD-025 | LOW | Validation drift (client vs server) |
| TD-028 | LOW | VARCHAR2(4000) catch-all columns |

---

## 7. Remediation Priority Matrix

```
                        EFFORT
                  Low          High
              ┌────────────┬────────────┐
       High   │ QUICK WINS │ MAJOR      │
              │            │ PROJECTS   │
              │ TD-004     │ TD-001     │
  I           │ TD-007     │ TD-002     │
  M           │ TD-008     │ TD-005     │
  P           │ TD-017     │ TD-009     │
  A           │ TD-018     │ TD-015     │
  C           │ TD-027     │ TD-023     │
  T           ├────────────┼────────────┤
              │ FILL-INS   │ DEFER      │
       Low    │            │            │
              │ TD-025     │ TD-016     │
              │ TD-028     │ TD-022     │
              │ TD-030     │ TD-026     │
              │ TD-031     │ TD-029     │
              └────────────┴────────────┘
```

**Recommended remediation order:**
1. **Immediate** (Sprint 0): TD-003 (remove cleartext creds), TD-004 (add lockout), TD-005 (fix SQL injection)
2. **Short-term** (Sprint 1-2): TD-001 (upgrade hashing), TD-002 (externalize key), TD-007 (fix race condition), TD-008 (read tax brackets from table)
3. **Medium-term** (Sprint 3-4): TD-009 (break circular dep), TD-010/TD-011 (leave bugs), TD-015 (bulk payroll)
4. **Long-term** (modernization): TD-023 (API integration), TD-016 (real-time reporting), TD-026 (consolidate logic)
