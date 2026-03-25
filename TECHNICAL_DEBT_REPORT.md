# Technical Debt Report

> **System**: HRMS (Human Resource Management System) v4.2  
> **Platform**: Oracle Forms 12c (12.2.1.4) / Oracle Database 19c  
> **Schema**: HRMS  
> **Assessment Date**: 2026-03-25

---

## Severity Definitions

| Severity | Definition | Action Required |
|----------|-----------|-----------------|
| **CRITICAL** | Active security vulnerability or data-corruption risk in production | Immediate remediation required |
| **HIGH** | Significant risk of incorrect results, data loss, or security exposure under normal use | Fix before any modernization effort |
| **MEDIUM** | Maintainability or correctness issue that increases risk over time | Address during modernization |
| **LOW** | Code quality or best-practice deviation with minimal production impact | Opportunistic cleanup |

---

## Summary by Category

| Category | Critical | High | Medium | Low | Total |
|----------|:--------:|:----:|:------:|:---:|:-----:|
| Security Vulnerabilities | 4 | 2 | 1 | 0 | 7 |
| Race Conditions & Data Integrity | 2 | 2 | 1 | 0 | 5 |
| Performance Anti-Patterns | 0 | 2 | 3 | 1 | 6 |
| Validation Drift | 0 | 2 | 2 | 0 | 4 |
| Architectural Debt | 0 | 1 | 3 | 2 | 6 |
| Operational Debt | 0 | 1 | 2 | 2 | 5 |
| **Total** | **6** | **10** | **12** | **5** | **33** |

---

## 1. Security Vulnerabilities

### SEC-001: MD5 Password Hashing (CRITICAL)

**Location**: `plsql/packages/PKG_SECURITY.pkb` — `hash_password` function  
**Description**: Passwords are hashed using `DBMS_CRYPTO.HASH_MD5`. MD5 is cryptographically broken and vulnerable to rainbow-table and collision attacks. An attacker with read access to the EMPLOYEES table can reverse passwords in seconds using precomputed tables.  
**Impact**: Complete credential compromise if database is breached.  
**Recommendation**: Replace with `DBMS_CRYPTO.HASH_SH256` (minimum) or bcrypt/scrypt via a Java stored procedure. Implement password salting. Force a password reset for all users after migration.

---

### SEC-002: Hard-Coded DBMS_CRYPTO Encryption Key (CRITICAL)

**Location**: `plsql/packages/PKG_SECURITY.pkb` — `encrypt_ssn` / `decrypt_ssn` functions  
**Description**: The AES-256 encryption key used for SSN encryption is hard-coded as a constant within the package body. Anyone with `SELECT` on `DBA_SOURCE` or schema-level access can read the key and decrypt all SSN values.  
**Impact**: PII exposure for all employees. Potential regulatory violation (HIPAA, state privacy laws).  
**Recommendation**: Move the encryption key to Oracle Wallet or an external key management system (KMS). Restrict `DBA_SOURCE` access. Re-encrypt all SSNs after key rotation.

---

### SEC-003: No Account Lockout on Failed Login (CRITICAL)

**Location**: `plsql/packages/PKG_SECURITY.pkb` — `authenticate` procedure  
**Description**: There is no tracking of failed login attempts and no lockout mechanism. An attacker can perform unlimited brute-force password guessing against the login form.  
**Impact**: Combined with SEC-001 (weak hashing), this makes credential compromise highly likely.  
**Recommendation**: Add a `FAILED_LOGIN_COUNT` and `LOCKED_UNTIL` column to EMPLOYEES or USER_SESSIONS. Lock accounts after 5 consecutive failures with exponential backoff. Log all failed attempts.

---

### SEC-004: Cleartext FTP Credentials in SYSTEM_PARAMETERS (CRITICAL)

**Location**: `data/seed/01_reference_data.sql`, `plsql/packages/PKG_INTEGRATION.pkb`  
**Description**: FTP server hostname, username, and password for integration file transfers are stored as plaintext rows in the SYSTEM_PARAMETERS table. Any user with `SELECT` access to SYSTEM_PARAMETERS can read these credentials.  
**Impact**: Unauthorized access to FTP server; potential data exfiltration of GL journals, benefits feeds, and payroll files.  
**Recommendation**: Move FTP credentials to Oracle Wallet or encrypted storage. Switch from FTP to SFTP/SCP. Restrict SYSTEM_PARAMETERS access to PKG_INTEGRATION owner.

---

### SEC-005: Password Transmitted in Cleartext (HIGH)

**Location**: `forms/xml-exports/HRMS_LOGIN.xml` — BTN_LOGIN WHEN-BUTTON-PRESSED trigger  
**Description**: The Oracle Forms applet transmits the password from the client to the Forms server over the network. Unless the Forms deployment uses HTTPS, passwords travel in cleartext. Even with HTTPS, the password value is passed as a Forms parameter (not a POST body), which may be logged.  
**Impact**: Credential interception via network sniffing.  
**Recommendation**: Ensure Forms Server is deployed behind HTTPS/TLS termination. In modernized architecture, use standard HTTPS POST with secure cookie-based sessions or JWT.

---

### SEC-006: Session Timeout Uses DB Server Time (HIGH)

**Location**: `plsql/packages/PKG_SECURITY.pkb` — `is_session_valid` function  
**Description**: Session validity is checked using `SYSDATE - LOGIN_TIME > (timeout_minutes / 1440)`. This uses database server time, not client activity time. If the DB server clock drifts or if the user is active but the server-side session timer expires, users are forced to re-authenticate mid-transaction.  
**Impact**: User disruption; potential data loss if session expires during unsaved form edits. No sliding window / activity-based timeout.  
**Recommendation**: Implement activity-based session tracking with a `LAST_ACTIVITY` timestamp updated on each request. Use a sliding 30-minute inactivity window.

---

### SEC-007: Grade-Based RBAC Without Role Table (MEDIUM)

**Location**: `plsql/packages/PKG_SECURITY.pkb` — `has_permission` function  
**Description**: Authorization is based on the employee's job grade level rather than explicit role assignments. Permissions are determined by hard-coded grade thresholds (e.g., grade >= 6 for PAYROLL access). There is no ROLES or USER_ROLES table.  
**Impact**: Cannot grant specific permissions without changing job grades. Cannot implement principle of least privilege. Difficult to audit who has access to what.  
**Recommendation**: Create ROLES and USER_ROLE_ASSIGNMENTS tables. Map permissions to roles rather than grade levels.

---

## 2. Race Conditions & Data Integrity

### RACE-001: Employee Number Generation via MAX()+1 (CRITICAL)

**Location**: `plsql/packages/PKG_EMPLOYEE.pkb` — `generate_emp_number` function  
**Description**: Employee numbers are generated using `SELECT MAX(EMP_NUMBER) + 1 FROM EMPLOYEES` rather than using `SEQ_EMP_NUMBER.NEXTVAL`. Under concurrent inserts, two sessions can read the same MAX value and generate duplicate employee numbers. The UNIQUE constraint on EMP_NUMBER will cause one insert to fail with `ORA-00001`.  
**Impact**: Insert failures during concurrent employee creation; lost work in Forms sessions.  
**Note**: `SEQ_EMP_NUMBER` exists but is never used. Additionally, all 25 sequences use `NOCACHE`, which eliminates the RAC gap risk but adds contention under high concurrency.  
**Recommendation**: Replace `MAX()+1` with `SEQ_EMP_NUMBER.NEXTVAL` formatted as `'EMP-' || LPAD(SEQ_EMP_NUMBER.NEXTVAL, 6, '0')`. Remove the MAX query entirely.

---

### RACE-002: Partial Commit in Payroll Calculation (CRITICAL)

**Location**: `plsql/packages/PKG_PAYROLL.pkb` — `calculate_payroll` procedure  
**Description**: The payroll calculation loop commits every 50 employees. If the procedure fails mid-run (e.g., at employee #75 of 200), employees #1-50 are committed but #51-75 are rolled back. The payroll run is left in an inconsistent state with some employees calculated and others not.  
**Impact**: Partial payroll processing; requires manual identification and re-processing of uncalculated employees. No mechanism to detect or resume from partial runs.  
**Recommendation**: Either commit only at the end of the full run, or implement a per-employee status flag in PAYROLL_DETAILS to track which employees were successfully processed. Add resume-from-failure capability.

---

### RACE-003: Leave Overlap Detection Ignores Half-Days (HIGH)

**Location**: `plsql/packages/PKG_LEAVE.pkb` — `check_leave_overlap` function  
**Description**: The overlap check queries `LEAVE_REQUESTS WHERE STATUS IN ('PENDING', 'APPROVED') AND date ranges overlap`. However, it does not account for `HALF_DAY_FLAG` or `HALF_DAY_PERIOD` (AM/PM). Two half-day requests on the same date (one AM, one PM) are incorrectly flagged as overlapping.  
**Impact**: Employees cannot submit legitimate AM + PM half-day requests on the same day.  
**Recommendation**: Add `HALF_DAY_FLAG` and `HALF_DAY_PERIOD` to the overlap query. Two half-day requests on the same date should only overlap if they share the same period (AM/AM or PM/PM).

---

### RACE-004: Leave Carryover Double-Expiry (HIGH)

**Location**: `plsql/packages/PKG_LEAVE.pkb` — `process_carryover` and `expire_carryover` procedures  
**Description**: If the `process_carryover` batch job runs twice in the same year (e.g., due to a retry or scheduling error), carryover days are doubled. Similarly, if `expire_carryover` runs twice, carryover is zeroed and then the second run has no effect — but if `process_carryover` runs again after expiry, it re-adds days from the previous year.  
**Impact**: Incorrect leave balances; employees may get more or fewer days than entitled.  
**Recommendation**: Add an idempotency check: `IF CARRYOVER_FROM_PREV > 0 AND CALENDAR_YEAR = current_year THEN SKIP`. Use a batch run log table to prevent duplicate execution.

---

### RACE-005: Soft Delete Trigger Conflicts with Forms DELETE (MEDIUM)

**Location**: `plsql/triggers/trg_employees.sql` — `TRG_EMP_INSTEAD_OF_DELETE`  
**Description**: The INSTEAD OF DELETE trigger converts physical deletes to soft deletes by setting `ACTIVE_FLAG = 'N'`. However, Oracle Forms issues a DELETE statement when the user presses the Delete key, expecting the row to disappear. The trigger silently converts this to an update, but the row remains visible in the Forms block until the user manually re-queries.  
**Impact**: User confusion; employees appear to still exist after "deletion". The documented workaround (`SET ACTIVE_FLAG='N'` then `CLEAR_RECORD`) must be coded into every form.  
**Recommendation**: In Forms, override the KEY-DELREC trigger to call `PKG_EMPLOYEE.terminate_employee` instead of issuing DELETE. Remove the INSTEAD OF DELETE trigger.

---

## 3. Performance Anti-Patterns

### PERF-001: All 25 Sequences Use NOCACHE (HIGH)

**Location**: `schema/sequences/hrms_sequences.sql`  
**Description**: Every sequence is defined with `NOCACHE`, meaning each `NEXTVAL` call requires a round-trip to the sequence dictionary. In a standard deployment, this is a serialization point. On Oracle RAC, this becomes a severe cross-instance contention bottleneck.  
**Impact**: Insert throughput limited by sequence allocation speed. Under concurrent payroll runs or batch imports, this becomes a bottleneck.  
**Recommendation**: Add `CACHE 20` (or higher) to high-volume sequences: `SEQ_PAYROLL_DETAIL`, `SEQ_LEAVE_ACCRUAL`, `SEQ_EMPLOYEE`, `SEQ_SALARY`. Accept minor gaps in sequence numbers.

---

### PERF-002: Denormalized Reporting Tables Stale During Business Hours (HIGH)

**Location**: `plsql/packages/PKG_REPORTING.pkb` — `refresh_reporting_tables` procedure  
**Description**: `PKG_REPORTING.refresh_reporting_tables` is designed as a nightly batch job that refreshes denormalized `RPT_*` tables. During business hours, all reports query stale data from the last nightly refresh. The procedure is currently a placeholder (`-- TODO: Implement refresh logic`) with no actual implementation.  
**Impact**: Reports show data that is up to 24 hours stale. For time-sensitive reports (headcount for board meetings, compliance audits), this is unacceptable.  
**Recommendation**: Implement materialized views with `REFRESH FAST ON DEMAND` at configurable intervals. For critical reports, query base tables directly (the views already exist for this purpose).

---

### PERF-003: Hard-Coded Fiscal Year Start Date (MEDIUM)

**Location**: `plsql/packages/PKG_REPORTING.pkb` — multiple report procedures  
**Description**: The fiscal year start is hard-coded as October 1 (`ADD_MONTHS(TRUNC(SYSDATE, 'YYYY'), 9)`). If the company's fiscal year changes, every report must be manually updated.  
**Impact**: Incorrect fiscal year calculations if the fiscal calendar changes. Maintenance burden for any fiscal year change.  
**Recommendation**: Move the fiscal year start month to SYSTEM_PARAMETERS and read it via `PKG_COMMON.get_param('FISCAL_YEAR_START_MONTH')`. Use this in all date range calculations.

---

### PERF-004: Hard-Coded 2024 Tax Brackets in PKG_PAYROLL (MEDIUM)

**Location**: `plsql/packages/PKG_PAYROLL.pkb` — `calculate_federal_tax`, `calculate_state_tax`  
**Description**: Federal and state tax brackets for 2024 are hard-coded as PL/SQL constants instead of reading from the `TAX_BRACKETS` table (which exists and is seeded). When tax rates change annually, the package body must be recompiled.  
**Impact**: Incorrect tax calculations for any year other than 2024. Package recompilation required annually, risking `ORA-04068` in active sessions.  
**Recommendation**: Read tax brackets from `TAX_BRACKETS` table dynamically. Cache them in a PL/SQL collection for performance.

---

### PERF-005: Payroll Commits Every 50 Employees (MEDIUM)

**Location**: `plsql/packages/PKG_PAYROLL.pkb` — `calculate_payroll`  
**Description**: The payroll loop commits every 50 employees to avoid long-running transactions. While this reduces undo segment usage, it creates partial-commit risk (see RACE-002) and generates excessive redo log switches. Each commit also releases row locks, meaning concurrent updates to SALARY_RECORDS or EMPLOYEES could interfere.  
**Impact**: Redo log contention during large payroll runs. Partial-commit data integrity risk.  
**Recommendation**: Use a savepoint-based approach: set savepoints every 50 employees but only commit at the end. If memory/undo is a concern, use DBMS_PARALLEL_EXECUTE for chunk-based processing with proper error handling.

---

### PERF-006: VARCHAR2(4000) Catch-All Columns (LOW)

**Location**: Multiple tables across all DDL files  
**Description**: Several columns use `VARCHAR2(4000)` (the maximum for non-CLOB types) when the business data would fit in much smaller columns. Examples include `REASON` columns, `COMMENTS`, and `DESCRIPTION` fields. While this doesn't waste disk space (VARCHAR2 stores only actual data), it affects PGA memory allocation for sorts and hash joins because Oracle allocates memory based on max column width.  
**Impact**: Suboptimal PGA memory usage during sorts and joins involving these columns.  
**Recommendation**: Review and right-size VARCHAR2 columns based on actual data distribution. Use CLOB only where text genuinely exceeds 4000 bytes.

---

## 4. Validation Drift

### VAL-001: Email Validation Rejects Valid Subdomains (HIGH)

**Location**:  
- Client: `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` — `validate_email`  
- Server: `plsql/packages/PKG_VALIDATION.pkb` — `validate_email_format`  
- Server: `plsql/packages/PKG_COMMON.pkb` — `is_valid_email`  

**Description**: The client-side (PLL) email validation uses a regex that rejects emails with subdomains (e.g., `user@mail.company.co.uk`). The server-side (PKG_VALIDATION) uses a slightly different regex that accepts them. This means an employee whose email contains a subdomain will be blocked at the Forms level but would pass server-side validation.  
**Impact**: Users with legitimate subdomain email addresses cannot be entered via Forms. Data entered via direct SQL or API bypass would pass server-side validation but fail if later edited in Forms.  
**Recommendation**: Consolidate email validation logic in PKG_VALIDATION and have the PLL library call it via database procedure call rather than implementing its own regex. Use a single source of truth for all validation rules.

---

### VAL-002: Salary Range Cache Staleness in Client-Side Validation (HIGH)

**Location**:  
- Client: `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` — `validate_salary_range`  
- Server: `plsql/packages/PKG_VALIDATION.pkb` — `validate_salary_for_grade`  

**Description**: The PLL library caches salary grade ranges in a PL/SQL table variable when the form opens. If an administrator updates JOB_GRADES salary ranges mid-session, the Forms client continues validating against stale cached values. The server-side validation always reads current values from the table.  
**Impact**: Salary changes may be rejected or accepted incorrectly if grade ranges were recently updated. A form restart is required to pick up new ranges.  
**Recommendation**: Either add a cache-invalidation mechanism (check a modification timestamp on JOB_GRADES) or remove client-side salary validation entirely and rely on server-side validation in the PRE-INSERT/PRE-UPDATE triggers.

---

### VAL-003: Hire Date Validation Differs Between Client and Server (MEDIUM)

**Location**:  
- Client: `forms/xml-exports/HRMS_EMPLOYEE.xml` — WHEN-VALIDATE-ITEM trigger  
- Server: `plsql/packages/PKG_EMPLOYEE.pkb` — `create_employee`  

**Description**: The Forms WHEN-VALIDATE-ITEM trigger rejects hire dates more than 90 days in the future (`HIRE_DATE > SYSDATE + 90`). The server-side `create_employee` procedure has its own validation but uses a different threshold (or none at all for future dates). The two validations are not synchronized.  
**Impact**: Inconsistent behavior depending on whether the employee is created via Forms or via a direct package call.  
**Recommendation**: Move the 90-day threshold to SYSTEM_PARAMETERS and read it in both the Forms trigger and the package procedure.

---

### VAL-004: Phone Format Validation Inconsistency (MEDIUM)

**Location**:  
- Client: `forms/libraries/HRMS_VALIDATION_LIB.pll.sql` — `validate_phone`  
- Server: `plsql/packages/PKG_VALIDATION.pkb` — `validate_phone_format`  
- Server: `plsql/packages/PKG_COMMON.pkb` — `is_valid_phone`  

**Description**: Phone validation exists in three places with slightly different rules. The PLL accepts US-format only (10 digits, optional hyphens/parens). `PKG_VALIDATION` accepts international prefixes (+1, +44, etc.). `PKG_COMMON.is_valid_phone` uses a different regex that permits extensions (x1234).  
**Impact**: International phone numbers accepted server-side but rejected client-side in Forms.  
**Recommendation**: Consolidate into a single `PKG_VALIDATION.validate_phone_format` function. Remove phone validation from `PKG_COMMON` and the PLL library.

---

## 5. Architectural Debt

### ARCH-001: Circular Dependency — PKG_EMPLOYEE ↔ PKG_PAYROLL (HIGH)

**Location**: `plsql/packages/PKG_EMPLOYEE.pkb`, `plsql/packages/PKG_PAYROLL.pkb`  
**Description**: `PKG_EMPLOYEE` calls `PKG_PAYROLL.create_salary_record` during employee creation, promotion, and rehire. `PKG_PAYROLL` calls `PKG_EMPLOYEE.get_employee` and `PKG_EMPLOYEE.is_active` during payroll calculation. This creates a compile-time and runtime circular dependency.  
**Impact**:  
- Fragile compilation order (all specs must compile before any body)  
- Cannot drop/recreate either package independently  
- Risk of `ORA-04068` (existing package state discarded) during hot patching  
- Impossible to unit test either package in isolation  
**Recommendation**: Extract salary management into a new `PKG_SALARY` package that both `PKG_EMPLOYEE` and `PKG_PAYROLL` depend on (breaking the cycle). Alternatively, use Oracle Advanced Queuing (AQ) to decouple the create-employee → create-salary-record flow.

---

### ARCH-002: Business Logic Duplicated Across Three Layers (MEDIUM)

**Location**: Forms triggers, PLL libraries, PL/SQL packages, and database triggers  
**Description**: Business rules are implemented redundantly in:  
1. **Forms triggers** (e.g., hire date validation in HRMS_EMPLOYEE.xml WHEN-VALIDATE-ITEM)  
2. **PLL libraries** (e.g., email/phone/salary validation in HRMS_VALIDATION_LIB)  
3. **PL/SQL packages** (e.g., same validations in PKG_VALIDATION, PKG_EMPLOYEE)  
4. **Database triggers** (e.g., audit columns in TRG_EMP_BEFORE_INSERT vs. Forms PRE-INSERT)  
**Impact**: Validation drift (see VAL-001 through VAL-004). Any business rule change must be applied in up to 4 places. High risk of inconsistency.  
**Recommendation**: Establish a single source of truth: PL/SQL packages for all business rules. Forms should call server-side procedures for validation. Remove client-side rule duplication.

---

### ARCH-003: No Unit Test Framework (MEDIUM)

**Location**: Entire codebase  
**Description**: There are no unit tests for any PL/SQL package, no test scripts, no test data fixtures, and no CI/CD pipeline. All testing is manual and relies on the Forms UI.  
**Impact**: Regression risk on every change. Cannot validate bug fixes without manual testing. Refactoring is extremely risky.  
**Recommendation**: Adopt utPLSQL for PL/SQL unit testing. Create test fixtures using the existing seed data scripts. Implement CI/CD with automated test runs.

---

### ARCH-004: Monolithic Package Bodies (MEDIUM)

**Location**: `PKG_EMPLOYEE.pkb` (967 lines), `PKG_PAYROLL.pkb` (898 lines), `PKG_LEAVE.pkb` (674 lines)  
**Description**: The three largest packages exceed 600 lines each. `PKG_EMPLOYEE` handles CRUD, lifecycle management (transfer/promote/terminate/rehire), org chart queries, employee number generation, and history logging — all in a single package.  
**Impact**: Difficult to read, review, and maintain. Long recompile times. High merge-conflict risk if multiple developers work on the same package.  
**Recommendation**: Decompose large packages by subdomain: `PKG_EMP_LIFECYCLE` (transfer/promote/terminate), `PKG_EMP_ORG` (org chart, hierarchy), keeping `PKG_EMPLOYEE` for core CRUD.

---

### ARCH-005: Mixed Naming Conventions (LOW)

**Location**: Entire codebase  
**Description**: Naming conventions are inconsistent:  
- Packages: `PKG_` prefix (consistent)  
- Triggers: `TRG_` prefix (consistent)  
- Views: `VW_` prefix (consistent)  
- Sequences: `SEQ_` prefix (consistent)  
- Tables: No prefix (but EMPLOYEE_HISTORY uses `_HISTORY` suffix while AUDIT_LOG uses `_LOG` suffix)  
- Columns: Mix of `_ID` suffixes, `_FLAG` suffixes, `_ENC` suffixes, `_ENCRYPTED` — not all consistent  
**Impact**: Minor readability issue. New developers need to learn the conventions by example.  
**Recommendation**: Document naming conventions. Standardize during modernization.

---

### ARCH-006: Dead Code / Stub Procedures (LOW)

**Location**:  
- `plsql/packages/PKG_INTEGRATION.pkb` — `import_time_attendance` (stub: `-- TODO: Implement CSV parsing`)  
- `plsql/packages/PKG_INTEGRATION.pkb` — `sync_org_structure` (stub: `-- TODO: Implement LDAP/AD sync`)  
- `plsql/packages/PKG_REPORTING.pkb` — `refresh_reporting_tables` (stub: `-- TODO: Implement refresh logic`)  

**Description**: Three procedures are stubs with no implementation. They exist in the package spec and are callable, but do nothing (or just log a message).  
**Impact**: Callers may assume these features work. No error is raised, so failures are silent.  
**Recommendation**: Either implement or explicitly raise `RAISE_APPLICATION_ERROR(-20999, 'Not implemented')` so callers know the feature is unavailable. Remove from Forms menus if applicable.

---

## 6. Operational Debt

### OPS-001: No Retry Logic for Integration Feeds (HIGH)

**Location**: `plsql/packages/PKG_INTEGRATION.pkb` — `generate_gl_journal`, `export_benefits_feed`  
**Description**: If UTL_FILE operations fail (directory not mounted, disk full, permission denied), the procedures raise an unhandled exception and the entire batch fails. There is no retry logic, no partial-write recovery, and no status tracking table for integration runs.  
**Impact**: Failed integration feeds require manual intervention. No alerting or automatic retry. GL postings and benefits enrollments may be missed.  
**Recommendation**: Add an `INTEGRATION_RUNS` status table. Implement retry with exponential backoff. Write to a temporary file first, then rename on success (atomic write pattern).

---

### OPS-002: Hard-Coded SMTP Server in PKG_NOTIFICATION (MEDIUM)

**Location**: `plsql/packages/PKG_NOTIFICATION.pkb` — `process_queue`  
**Description**: The SMTP server hostname (`smtp.internal.company.com`) and port (25) are hard-coded in the package body. Changing the mail server requires recompiling the package.  
**Impact**: Package recompilation needed for any mail server change. Risk of `ORA-04068` during recompilation.  
**Recommendation**: Move SMTP settings to SYSTEM_PARAMETERS. Read via `PKG_COMMON.get_param('SMTP_HOST')` and `PKG_COMMON.get_param('SMTP_PORT')`.

---

### OPS-003: No Rate Limiting on Notifications (MEDIUM)

**Location**: `plsql/packages/PKG_NOTIFICATION.pkb` — `process_queue`  
**Description**: The notification queue processor sends all pending notifications without any rate limiting. A bulk operation (e.g., generating 200 performance reviews) can flood the mail server with 200+ emails simultaneously.  
**Impact**: SMTP server overload. Potential for being flagged as spam. No throttling for failed sends.  
**Recommendation**: Add configurable rate limiting (e.g., max 10 emails per minute). Implement batch windowing for bulk operations.

---

### OPS-004: HTML Email Templates as String Constants (LOW)

**Location**: `plsql/packages/PKG_NOTIFICATION.pkb`  
**Description**: Email HTML templates are constructed as concatenated VARCHAR2 strings within the package body. Any template change requires recompiling the package.  
**Impact**: Maintenance burden for template changes. No designer-friendly workflow for HTML email authoring.  
**Recommendation**: Move templates to a NOTIFICATION_TEMPLATES table with HTML CLOB content and placeholder tokens. Populate via merge/replace at send time.

---

### OPS-005: Payroll Overtime Does Not Account for Holidays (LOW)

**Location**: `plsql/packages/PKG_PAYROLL.pkb` — `calculate_employee_pay`  
**Description**: Overtime calculation uses a flat >40 hours/week threshold without checking the HOLIDAYS table. Hours worked on company holidays should be paid at a premium rate (typically 1.5x or 2x), but the current logic treats holiday hours the same as regular weekday hours.  
**Impact**: Employees working holidays may be underpaid. Potential labor law compliance issue.  
**Recommendation**: Cross-reference hours against HOLIDAYS table. Apply holiday premium rate from a configurable SYSTEM_PARAMETER.

---

## 7. Modernization Risk Matrix

The following table maps each debt item to its impact on a modernization effort (e.g., migration to Java/Spring Boot):

| ID | Debt Item | Modernization Risk | Must Fix Before Migration? |
|----|-----------|-------------------|:-------------------------:|
| SEC-001 | MD5 password hashing | Password migration strategy needed | Yes |
| SEC-002 | Hard-coded encryption key | Key migration to KMS required | Yes |
| SEC-003 | No account lockout | Implement in new auth layer | Yes |
| SEC-004 | Cleartext FTP credentials | Secrets management in new system | Yes |
| SEC-005 | Cleartext password transmission | Resolved by HTTPS + REST API | No (auto-fixed) |
| SEC-006 | Session timeout uses DB time | JWT/token-based sessions resolve this | No (auto-fixed) |
| SEC-007 | Grade-based RBAC | Design proper RBAC for new system | Yes |
| RACE-001 | MAX()+1 employee number | Use JPA @GeneratedValue with sequence | No (auto-fixed) |
| RACE-002 | Partial payroll commit | Spring Batch chunk processing | No (auto-fixed) |
| RACE-003 | Half-day overlap bug | Port fix to new leave service | Yes |
| RACE-004 | Carryover double-expiry | Port fix to new leave service | Yes |
| RACE-005 | Soft delete trigger conflict | JPA @SQLDelete annotation | No (auto-fixed) |
| PERF-001 | NOCACHE sequences | JPA allocationSize > 1 | No (auto-fixed) |
| PERF-002 | Stale reporting tables | Materialized views or live queries | No (redesign) |
| PERF-003 | Hard-coded fiscal year | Externalize to config | Yes |
| PERF-004 | Hard-coded tax brackets | Read from DB or external service | Yes |
| PERF-005 | Partial commit in payroll | Spring Batch handles this | No (auto-fixed) |
| PERF-006 | VARCHAR2(4000) overuse | JPA column definitions | No (cosmetic) |
| VAL-001 | Email validation drift | Single Java validation layer | No (auto-fixed) |
| VAL-002 | Salary range cache | Real-time validation in service | No (auto-fixed) |
| VAL-003 | Hire date threshold drift | Single Java validation layer | No (auto-fixed) |
| VAL-004 | Phone format inconsistency | Single Java validation layer | No (auto-fixed) |
| ARCH-001 | Circular dependency | Clean module boundaries in Java | No (redesign) |
| ARCH-002 | Logic in 3 layers | Single service layer in Java | No (auto-fixed) |
| ARCH-003 | No unit tests | Write tests for Java services | No (new tests) |
| ARCH-004 | Monolithic packages | Decompose into Java services | No (redesign) |
| ARCH-005 | Naming inconsistency | Java naming conventions | No (cosmetic) |
| ARCH-006 | Dead code / stubs | Don't port unimplemented stubs | No (skip) |
| OPS-001 | No retry for integrations | Spring Integration retry patterns | No (redesign) |
| OPS-002 | Hard-coded SMTP | Spring Mail externalized config | No (auto-fixed) |
| OPS-003 | No rate limiting | Spring rate limiter | No (redesign) |
| OPS-004 | HTML templates as strings | Thymeleaf or similar | No (redesign) |
| OPS-005 | Holiday overtime bug | Port fix to new payroll service | Yes |

**Summary**: 10 of 33 items must be addressed before or during migration. 12 items are automatically resolved by modern frameworks. 11 items require conscious redesign in the new architecture.
