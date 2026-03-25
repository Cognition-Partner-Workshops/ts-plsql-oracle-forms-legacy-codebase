# HRMS Migration Strategy Assessment

## Executive Summary

This document evaluates three migration approaches for the HRMS v4.2 Oracle Forms/PL/SQL application: **Strangler Fig** (incremental replacement), **Big-Bang Rewrite** (complete replacement in Java/React), and **Re-Platform to APEX** (Oracle Application Express). Each functional area is assessed independently, with a recommended approach based on complexity, risk, dependencies, and business continuity requirements.

**Overall Recommendation:** Strangler Fig pattern for the majority of functional areas, with a phased 18-24 month timeline. The circular dependency between Employee Management and Payroll requires careful sequencing (see MODULE_ORDERING.md).

---

## System Overview

| Attribute | Value |
|-----------|-------|
| Current Platform | Oracle Forms 12c + Oracle Database 19c |
| PL/SQL Packages | 11 packages (~7,000 lines) |
| Forms Modules | 6 XML-exported forms (~1,400 lines) |
| Database Tables | 30 tables across 4 DDL files |
| Database Views | 6 views |
| Sequences | 25 |
| Concurrent Users | ~200 |
| Target Stack | Java (Spring Boot) + React SPA + PostgreSQL/Oracle |

---

## Functional Areas

### 1. Authentication & Session Management

**Current State:** HRMS_LOGIN form authenticates via `PKG_SECURITY.authenticate()`, which looks up employees by email, creates a `USER_SESSIONS` record, and stores session ID in Oracle Forms `GLOBAL` variables. Permissions are based on a simplified grade-based model in `PKG_SECURITY.has_permission()`.

**Complexity:** Low-Medium (238 lines in PKG_SECURITY body, 131 lines in HRMS_LOGIN form)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Deploy a modern auth service (Spring Security + JWT/OAuth2) first. Route new requests through the modern auth layer while keeping the legacy Forms login operational. Legacy forms can validate tokens via a compatibility shim. **Recommended.** |
| **Big-Bang Rewrite** | Replace the entire auth stack at once with Spring Security, JWT tokens, OAuth2/OIDC. Clean break from MD5 hashing and hard-coded encryption keys. Risk: all modules must switch simultaneously. |
| **Re-Platform (APEX)** | APEX has built-in authentication schemes (APEX accounts, LDAP, Social Sign-In). Minimal effort to set up, but locks into Oracle ecosystem. |

**Known Technical Debt to Address:**
- MD5 password hashing (should be bcrypt/Argon2)
- Hard-coded DBMS_CRYPTO key (`HR$ystem_3ncrypt10n_K3y_2024!!`)
- No account lockout after failed attempts
- Session timeout uses DB server time, not app server time
- Timing attack vulnerability in authentication
- No CAPTCHA or 2FA support

**Recommendation:** **Strangler Fig.** Authentication is the ideal first module to migrate because every other module depends on it, and the security debt is severe. Deploy modern auth as a standalone service, then migrate other modules behind it.

---

### 2. Employee Management

**Current State:** HRMS_EMPLOYEE form (539 lines, 4 tab pages, 5 data blocks, 8 LOVs) backed by `PKG_EMPLOYEE` (967 lines). Handles CRUD, transfers, promotions, terminations, rehires, org chart. Master-detail relationships with salary records, dependents, and history.

**Complexity:** High (largest form + largest package, circular dependency with PKG_PAYROLL)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Build a React-based employee profile UI alongside the legacy form. Route new features (self-service profile editing, org chart visualization) to the modern UI while complex workflows (transfers, terminations) remain on Forms until validated. **Recommended.** |
| **Big-Bang Rewrite** | Complete Spring Boot REST API + React SPA for all employee functions. Most comprehensive but highest risk given the 967-line package with complex lifecycle workflows (transfer, promote, terminate, rehire) and circular dependency with Payroll. |
| **Re-Platform (APEX)** | APEX Interactive Reports and Forms can replicate the multi-tab layout quickly. Master-detail relationships are natively supported. However, the complex lifecycle logic in PKG_EMPLOYEE would still need refactoring. |

**Key Challenges:**
- Circular dependency with `PKG_PAYROLL` (salary validation on create, promote, rehire)
- `generate_emp_number` has race condition (`MAX()+1` without locking)
- `search_employees` has SQL injection vulnerability (string concatenation)
- `get_org_chart` recursive query times out for >500 employees
- `PHOTO_BLOB` column needs modern file storage (S3/object storage)
- Business logic split between Forms triggers (WHEN-VALIDATE-ITEM, PRE-INSERT) and PKG_EMPLOYEE

**Recommendation:** **Strangler Fig.** Start with read-only views and self-service features in React. Migrate write operations module by module, resolving the circular dependency with Payroll via an interface/facade pattern.

---

### 3. Payroll Processing

**Current State:** HRMS_PAYROLL form (167 lines, 3 tab pages) backed by `PKG_PAYROLL` (898 lines). Manages salary records, pay periods, payroll runs (create, calculate, approve, reverse), and tax calculations (federal, state, FICA, Medicare).

**Complexity:** Very High (complex tax calculations, regulatory compliance, circular dependency)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Run modern payroll calculation engine in parallel with legacy for validation. Phase 1: Modern salary management + pay period APIs. Phase 2: Tax calculation engine (extract hard-coded brackets to config). Phase 3: Full payroll run processing. **Recommended with caution.** |
| **Big-Bang Rewrite** | Rebuild payroll from scratch in Java with proper tax calculation libraries. Eliminates hard-coded 2024 tax brackets and row-by-row cursor processing. Very high risk: payroll errors have direct financial and legal consequences. |
| **Re-Platform (APEX)** | APEX can replicate the UI, but the core payroll calculation logic remains PL/SQL. Does not solve the fundamental issues (hard-coded brackets, cursor-loop performance, partial commits). Least benefit for highest-complexity area. |

**Key Challenges:**
- Hard-coded 2024 tax brackets (`c_ss_wage_base_2024 = 168600`, `c_standard_deduction_single = 14600`)
- Row-by-row cursor processing for payroll calculation (should be bulk)
- Partial commits every 50 employees during calculation (atomicity issue)
- Overtime calculation does not account for holidays
- YTD accumulation resets incorrectly for mid-year hires
- Circular dependency with PKG_EMPLOYEE

**Recommendation:** **Strangler Fig.** Payroll requires the most conservative approach. Run dual calculations (legacy + modern) for at least 2 pay periods before cutover. Extract tax brackets to a configurable data store immediately.

---

### 4. Leave Management

**Current State:** HRMS_LEAVE form (220 lines, 4 tab pages) backed by `PKG_LEAVE` (674 lines). Handles leave requests (submit, approve, reject, cancel), balance tracking, monthly accrual batch processing, and carryover management.

**Complexity:** Medium (well-contained module with limited external dependencies)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Build modern leave request UI (React) with REST API (Spring Boot). Migrate read operations first (balance display, calendar view), then write operations (submit, approve). Batch accrual can remain PL/SQL initially. **Recommended.** |
| **Big-Bang Rewrite** | Complete leave management system in Java/React. Relatively self-contained, making this a good candidate for a standalone rewrite if parallel development resources are available. |
| **Re-Platform (APEX)** | APEX Interactive Grid for leave requests + Calendar widget for team view. Quick turnaround. Accrual batch jobs remain as PL/SQL (DBMS_SCHEDULER). |

**Key Challenges:**
- Half-day overlap detection bug (doesn't account for AM/PM periods correctly)
- Carryover expiry job double-expires if run twice on same day (not idempotent)
- Holiday detection only checks exact date match, not observed dates
- Balance calculation uses virtual column (`GENERATED ALWAYS AS`) which may need re-implementation

**Recommendation:** **Strangler Fig.** Leave management is the best candidate for early migration after Authentication. It has clear boundaries, limited dependencies (only PKG_EMPLOYEE for employee validation), and high user visibility for demonstrating migration progress.

---

### 5. Performance Reviews

**Current State:** HRMS_PERFORMANCE form (132 lines, 3 tab pages) backed by `PKG_PERFORMANCE` (98 lines spec). Manages review cycles, self-assessments, manager reviews, goal tracking, and rating distribution.

**Complexity:** Low-Medium (smallest form, well-defined workflow, master-detail patterns)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Build a modern review portal in React. Good candidate for early migration since it's relatively independent. Goal tracking and CLOB-based assessments map well to a modern rich-text editor experience. **Recommended.** |
| **Big-Bang Rewrite** | Simple enough to rewrite completely. Two master-detail relationships (Cycle->Review->Goal) map directly to a REST API with nested resources. |
| **Re-Platform (APEX)** | APEX supports CLOB editing and master-detail well. Rating calibration views could use Interactive Reports. Quick win. |

**Key Challenges:**
- CLOB columns for assessments (SELF_ASSESSMENT, MANAGER_ASSESSMENT, etc.) need rich text support
- Rating calibration workflow not fully implemented in current code
- Master-detail relationships (CYCLE_REVIEW_REL, REVIEW_GOAL_REL) need careful handling

**Recommendation:** **Strangler Fig.** This module offers an excellent opportunity to demonstrate modern UI capabilities (rich text editing, interactive dashboards) while migrating a low-risk functional area.

---

### 6. Reporting & Analytics

**Current State:** `PKG_REPORTING` (64 lines spec) provides headcount, compensation, turnover, new hires, leave utilization, payroll summary, and EEO compliance reports. Uses denormalized reporting tables refreshed nightly.

**Complexity:** Medium (depends on PKG_EMPLOYEE, PKG_PAYROLL, PKG_COMMON)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Replace with a modern reporting/BI tool (e.g., Metabase, Grafana, or embedded React dashboards). Can read from the same Oracle DB initially. Decouple report generation from the transactional packages. **Recommended.** |
| **Big-Bang Rewrite** | Build custom reporting dashboards in React with server-side data aggregation. Requires re-implementing all report queries. |
| **Re-Platform (APEX)** | APEX excels at reporting with Interactive Reports, Charts, and Pivot widgets. Strongest candidate for APEX re-platform if other modules remain on Oracle. |

**Key Challenges:**
- Denormalized reporting tables stale during business hours
- Hard-coded fiscal year start (Oct 1) in `PKG_COMMON.get_fiscal_year()`
- Reports currently generated via Oracle Reports (.rdf) which are also legacy
- Some reports use REF CURSOR outputs that need transformation

**Recommendation:** **Strangler Fig.** Replace with a modern BI layer that reads directly from the database. This provides immediate value without touching transactional logic.

---

### 7. External Integrations

**Current State:** `PKG_INTEGRATION` (51 lines spec) handles GL journal posting, benefits feed (ADP format), time & attendance import, and org structure sync. All use flat file exchange via `UTL_FILE`.

**Complexity:** Medium (file-based integration patterns, vendor-specific formats)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Replace file-based integrations with REST APIs or message queues incrementally. Start with GL posting (most critical), then benefits feed. **Recommended.** |
| **Big-Bang Rewrite** | Rebuild all integrations using modern patterns (REST, webhooks, message queues). Requires coordination with external systems (ERP/GL, ADP, time system). |
| **Re-Platform (APEX)** | APEX can call REST APIs via `APEX_WEB_SERVICE`, but the core integration logic remains PL/SQL. Limited benefit. |

**Key Challenges:**
- `UTL_FILE` flat file exchange (not API-based)
- Cleartext FTP credentials stored in `SYSTEM_PARAMETERS` table
- No retry logic for failed transfers
- ADP-specific format (vendor lock-in)
- GL posting requires double-entry accounting accuracy

**Recommendation:** **Strangler Fig.** Replace integrations opportunistically as external system contracts come up for renewal. Prioritize eliminating cleartext FTP credentials and adding retry/error handling.

---

### 8. Common Utilities & Cross-Cutting Concerns

**Current State:** `PKG_COMMON` (284 lines), `PKG_AUDIT` (33 lines spec), `PKG_NOTIFICATION` (43 lines spec), `PKG_VALIDATION` (48 lines spec), and PLL libraries (`HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB`).

**Complexity:** Low (utility functions, but deeply embedded across all modules)

| Approach | Assessment |
|----------|-----------|
| **Strangler Fig** | Build equivalent utility libraries in Java/TypeScript. Create a compatibility layer that mirrors the PL/SQL API. Shared validation logic should be consolidated (currently drifts between Forms PLL and PKG_VALIDATION). **Recommended.** |
| **Big-Bang Rewrite** | Straightforward to rewrite; these are stateless utility functions. |
| **Re-Platform (APEX)** | Most utilities work as-is in PL/SQL. PLL libraries not needed in APEX. |

**Key Challenges:**
- Validation drift between `HRMS_VALIDATION_LIB` (client-side) and `PKG_VALIDATION` (server-side)
- `HRMS_VALIDATION_LIB.validate_email` has known bug (rejects valid subdomains)
- `PKG_NOTIFICATION` has hard-coded SMTP server, no rate limiting, HTML templates as string constants
- `PKG_COMMON.log_error` writes to `AUDIT_LOG` table using autonomous transaction

**Recommendation:** **Strangler Fig.** Migrate utilities in lockstep with the modules that use them. Consolidate client/server validation into a single source of truth.

---

## Approach Comparison Matrix

| Criterion | Strangler Fig | Big-Bang Rewrite | Re-Platform (APEX) |
|-----------|:------------:|:----------------:|:------------------:|
| Business continuity risk | Low | **Very High** | Low |
| Time to first value | 2-3 months | 12-18 months | 1-2 months |
| Total migration timeline | 18-24 months | 12-18 months | 3-6 months |
| Technology modernization | Full | Full | Partial |
| Oracle license dependency | Eliminated | Eliminated | **Retained** |
| Development team ramp-up | Gradual | **Immediate full team** | Minimal (PL/SQL reuse) |
| Risk of data inconsistency | Medium (dual systems) | Low (single cutover) | Low |
| Rollback capability | High (per module) | **None** | Medium |
| Long-term maintainability | High | High | Medium |
| Solves circular dependency | Yes (with facade) | Yes (clean design) | No |
| Addresses security debt | Yes (incrementally) | Yes (all at once) | Partially |

---

## Recommended Overall Strategy

### Phase 1: Foundation (Months 1-3)
1. **Authentication & Security** - Deploy modern auth service (Spring Security + JWT)
2. **Common Utilities** - Build Java/TypeScript utility libraries
3. **Anti-Corruption Layer** - Create API gateway/facade between legacy and modern systems

### Phase 2: High-Visibility Wins (Months 4-8)
4. **Leave Management** - First full module migration (clear boundaries, high user visibility)
5. **Performance Reviews** - Low-risk module with opportunity to showcase modern UX
6. **Reporting** - Replace with modern BI dashboards

### Phase 3: Core Modules (Months 9-18)
7. **Employee Management** - Phased migration (read-only first, then write operations)
8. **Payroll Processing** - Conservative dual-run approach with parallel validation

### Phase 4: Cleanup (Months 19-24)
9. **External Integrations** - Modernize as contracts allow
10. **Legacy Decommission** - Remove Oracle Forms, consolidate on modern stack

### Decision Gate Criteria
Before proceeding from each phase to the next:
- All migrated modules pass regression tests
- Performance benchmarks meet or exceed legacy system
- No P1/P2 production incidents attributed to migrated modules
- User acceptance testing completed for each module
- Data consistency verified between legacy and modern systems (where dual-running)
