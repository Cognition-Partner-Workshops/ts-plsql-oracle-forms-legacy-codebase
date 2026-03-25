# Oracle Forms Legacy HR System

A representative Oracle Forms 12c legacy Human Resources Management System (HRMS), designed for modernization analysis and migration workshops. This codebase models a typical enterprise Oracle Forms application with PL/SQL business logic, database schemas, form definitions, and sample data.

## Application Overview

The **HR Management System** (HRMS) is a multi-module Oracle Forms application used by enterprise HR departments to manage:

- **Employee Records** — hire, transfer, terminate, personal details, job history
- **Department & Organization** — department hierarchy, cost centers, reporting lines
- **Payroll Processing** — salary calculations, deductions, tax withholding, pay runs
- **Leave Management** — leave requests, approvals, balance tracking, accrual rules
- **Performance Reviews** — annual review cycles, ratings, goal tracking
- **Reporting** — headcount, compensation analysis, turnover, compliance

The system was originally built in Oracle Forms 6i (circa 2002), upgraded to Forms 11g (2012), and is currently running on Forms 12c with Oracle Database 19c. It serves approximately 200 concurrent users across 3 regional offices.

## Technology Stack

| Component              | Technology                                  |
| :--------------------- | :------------------------------------------ |
| Client / Presentation  | Oracle Forms 12c (Java Applet / Web Start)  |
| Application Server     | Oracle WebLogic 12c                         |
| Database               | Oracle Database 19c                         |
| Business Logic         | PL/SQL Packages, Procedures, and Triggers   |
| Reporting Engine       | Oracle Reports (.rdf / .rep)                |

## Architecture

```
                    +-----------------------+
                    |   Oracle Forms 12c    |
                    |   Application Server  |
                    +-----------+-----------+
                                |
                    +-----------+-----------+
                    |   Oracle WebLogic     |
                    |   12c Server          |
                    +-----------+-----------+
                                |
          +---------------------+---------------------+
          |                     |                      |
+---------+--------+  +---------+--------+  +----------+-------+
| Forms Modules    |  | PL/SQL Packages  |  | Oracle Reports   |
| (.fmb/.fmx)     |  | & Procedures     |  | (.rdf/.rep)      |
| 6 forms          |  | 12 packages      |  |                  |
+------------------+  +------------------+  +------------------+
          |                     |                      |
          +---------------------+---------------------+
                                |
                    +-----------+-----------+
                    |   Oracle Database     |
                    |   19c (HRMS schema)   |
                    |   42 tables           |
                    |   15 views            |
                    |   200+ triggers       |
                    +-----------------------+
```

## Directory Structure

```
ts-plsql-oracle-forms-legacy-codebase/
├── forms/
│   ├── xml-exports/              # XML exports of Oracle Forms modules (.fmb -> .xml)
│   │   ├── HRMS_EMPLOYEE.xml             # Employee maintenance form
│   │   ├── HRMS_PAYROLL.xml              # Payroll processing form
│   │   ├── HRMS_LEAVE.xml                # Leave request and approval form
│   │   ├── HRMS_PERFORMANCE.xml          # Performance review form
│   │   ├── HRMS_LOGIN.xml                # Login and authentication form
│   │   └── HRMS_MENU.xml                 # Main menu navigation form
│   ├── libraries/                # Shared PL/SQL libraries (.pll)
│   │   ├── HRMS_COMMON_LIB.pll.sql      # Common utility library
│   │   └── HRMS_VALIDATION_LIB.pll.sql  # Shared validation routines
│   └── menus/                    # Menu module definitions
│       └── HRMS_MENU.mmb.sql            # Role-based menu system
├── plsql/
│   ├── packages/                 # PL/SQL package specifications (.pks) and bodies (.pkb)
│   │   ├── PKG_EMPLOYEE.pks / .pkb      # Employee lifecycle management
│   │   ├── PKG_PAYROLL.pks / .pkb       # Payroll engine
│   │   ├── PKG_LEAVE.pks / .pkb         # Leave management
│   │   ├── PKG_PERFORMANCE.pks / .pkb   # Performance reviews
│   │   ├── PKG_SECURITY.pks / .pkb      # Authentication & authorization
│   │   ├── PKG_AUDIT.pks / .pkb         # Audit trail logging
│   │   ├── PKG_NOTIFICATION.pks / .pkb  # Email/notification dispatch
│   │   ├── PKG_REPORTING.pks / .pkb     # Report data generation
│   │   ├── PKG_COMMON.pks / .pkb        # Shared utilities & constants
│   │   ├── PKG_VALIDATION.pks / .pkb    # Business rule validation
│   │   └── PKG_INTEGRATION.pks / .pkb   # External system integration
│   └── triggers/                 # Database triggers
│       ├── trg_audit.sql                 # Audit trail triggers
│       └── trg_employees.sql             # Employee table triggers
├── schema/
│   ├── tables/                   # CREATE TABLE DDL
│   │   ├── 01_core_tables.sql           # Departments, locations, employees, etc.
│   │   ├── 02_payroll_tables.sql        # Salary, pay elements, payroll runs
│   │   ├── 03_leave_tables.sql          # Leave types, requests, balances
│   │   └── 04_performance_tables.sql    # Review cycles, ratings, goals
│   ├── views/                    # CREATE VIEW definitions
│   │   └── hrms_views.sql               # All view definitions
│   └── sequences/                # Sequence definitions
│       └── hrms_sequences.sql           # Surrogate key generators
├── data/
│   └── seed/                     # Sample/seed data (INSERT scripts)
│       ├── 01_reference_data.sql        # Reference/lookup data
│       └── 02_employee_data.sql         # Sample employee records
└── README.md
```

## Database Setup

To set up the HRMS schema in an Oracle 19c database, run the scripts in the following order:

1. **Schema objects** — execute table DDL scripts in order:
   ```
   schema/tables/01_core_tables.sql
   schema/tables/02_payroll_tables.sql
   schema/tables/03_leave_tables.sql
   schema/tables/04_performance_tables.sql
   ```
2. **Sequences** — create surrogate key generators:
   ```
   schema/sequences/hrms_sequences.sql
   ```
3. **Views** — create reporting and convenience views:
   ```
   schema/views/hrms_views.sql
   ```
4. **PL/SQL packages** — compile in dependency order (foundation packages first):
   ```
   plsql/packages/PKG_COMMON.pks  → PKG_COMMON.pkb
   plsql/packages/PKG_AUDIT.pks   → PKG_AUDIT.pkb
   plsql/packages/PKG_SECURITY.pks → PKG_SECURITY.pkb
   plsql/packages/PKG_VALIDATION.pks → PKG_VALIDATION.pkb
   plsql/packages/PKG_NOTIFICATION.pks → PKG_NOTIFICATION.pkb
   plsql/packages/PKG_EMPLOYEE.pks → PKG_EMPLOYEE.pkb
   plsql/packages/PKG_PAYROLL.pks → PKG_PAYROLL.pkb
   plsql/packages/PKG_LEAVE.pks  → PKG_LEAVE.pkb
   plsql/packages/PKG_PERFORMANCE.pks → PKG_PERFORMANCE.pkb
   plsql/packages/PKG_REPORTING.pks → PKG_REPORTING.pkb
   plsql/packages/PKG_INTEGRATION.pks → PKG_INTEGRATION.pkb
   ```
5. **Triggers** — create database triggers:
   ```
   plsql/triggers/trg_employees.sql
   plsql/triggers/trg_audit.sql
   ```
6. **Seed data** — load reference and sample data:
   ```
   data/seed/01_reference_data.sql
   data/seed/02_employee_data.sql
   ```

> **Note:** `PKG_EMPLOYEE` and `PKG_PAYROLL` have a circular dependency. You may need to compile specifications first, then bodies, to resolve this.

## Key Technical Characteristics

### Oracle Forms Specifics
- **Form triggers**: `WHEN-NEW-FORM-INSTANCE`, `WHEN-VALIDATE-ITEM`, `WHEN-BUTTON-PRESSED`, `POST-QUERY`, `PRE-INSERT`, `PRE-UPDATE`
- **LOV (List of Values)**: Record groups with dynamic WHERE clauses
- **Canvas/block architecture**: Multiple data blocks per form, master-detail relationships
- **PLL libraries**: Shared PL/SQL libraries (`HRMS_COMMON_LIB`, `HRMS_VALIDATION_LIB`) attached to all forms
- **Menu modules (.mmb)**: Role-based menu system with security (`HRMS_MENU.mmb.sql`)

### PL/SQL Patterns
- Heavy use of `DBMS_OUTPUT`, `UTL_FILE`, `UTL_MAIL` built-in packages
- Cursor-based processing (row-by-row) for batch operations
- Exception handling with custom error codes (`-20001` to `-20999`)
- Dynamic SQL via `EXECUTE IMMEDIATE` in several procedures
- Global package variables for session state management
- Implicit cursors and `%ROWTYPE` / `%TYPE` declarations

### Database Patterns
- Surrogate keys via sequences + `BEFORE INSERT` triggers
- Soft deletes (`ACTIVE_FLAG CHAR(1) DEFAULT 'Y'`)
- Audit columns on every table (`CREATED_BY`, `CREATED_DATE`, `MODIFIED_BY`, `MODIFIED_DATE`)
- History tables (`_HIST` suffix) for change tracking
- Denormalized reporting tables (refreshed nightly by batch jobs)

## Known Technical Debt

- No unit tests — all testing is manual via Forms
- Business logic split between Forms triggers and database packages (no clear boundary)
- Several packages exceed 3,000 lines
- Hard-coded configuration values in package bodies
- `VARCHAR2(4000)` used as catch-all for text fields
- Mixed naming conventions (some `CAMELCASE`, some `UNDERSCORE_CASE`)
- Dead code from decommissioned modules still present
- Circular package dependency between `PKG_EMPLOYEE` and `PKG_PAYROLL`
- Race condition in employee number generation (`PKG_EMPLOYEE` uses `MAX()+1` instead of the `SEQ_EMP_NUMBER` sequence)

## Module Dependency Map

```
PKG_COMMON ──────────────────────────────────────────────┐
    │                                                     │
    ├── PKG_AUDIT                                         │
    │       │                                             │
    ├── PKG_SECURITY                                      │
    │                                                     │
    ├── PKG_VALIDATION                                    │
    │                                                     │
    ├── PKG_NOTIFICATION                                  │
    │                                                     │
    ├── PKG_EMPLOYEE ←──── circular ────→ PKG_PAYROLL     │
    │       │                    │                         │
    │       ├── PKG_LEAVE        │                         │
    │       │                    │                         │
    │       └── PKG_PERFORMANCE  │                         │
    │                            │                         │
    ├── PKG_REPORTING ───────────┘                         │
    │                                                     │
    └── PKG_INTEGRATION ──────────────────────────────────┘
```

## License

MIT
