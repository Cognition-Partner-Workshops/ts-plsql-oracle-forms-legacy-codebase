#!/usr/bin/env python3
"""
HRMS Oracle Database Setup Script
Connects to Oracle XE, creates the HRMS schema, runs DDL, loads seed data,
and compiles PL/SQL packages.

Usage:
    python3 scripts/setup_database.py [--reset]

Environment variables (required):
    ORACLE_HOST     - Database host (default: localhost)
    ORACLE_PORT     - Database port (default: 1521)
    ORACLE_SERVICE  - Service name (default: XEPDB1)
    ORACLE_SYS_PWD  - SYS/SYSTEM password (required)
    HRMS_USER       - HRMS schema user (required)
    HRMS_PASSWORD   - HRMS schema password (required)
"""

import os
import sys
import glob
import argparse
import subprocess
import shutil

import oracledb


def get_config():
    config = {
        "host": os.environ.get("ORACLE_HOST", "localhost"),
        "port": int(os.environ.get("ORACLE_PORT", "1521")),
        "service": os.environ.get("ORACLE_SERVICE", "XEPDB1"),
        "sys_password": os.environ.get("ORACLE_SYS_PWD", ""),
        "hrms_user": os.environ.get("HRMS_USER", ""),
        "hrms_password": os.environ.get("HRMS_PASSWORD", ""),
    }
    missing = [k for k in ("sys_password", "hrms_user", "hrms_password") if not config[k]]
    if missing:
        env_names = {"sys_password": "ORACLE_SYS_PWD", "hrms_user": "HRMS_USER",
                     "hrms_password": "HRMS_PASSWORD"}
        print(f"ERROR: Missing required env vars: {', '.join(env_names[k] for k in missing)}")
        sys.exit(1)
    return config


def get_sys_connection(config):
    dsn = f'{config["host"]}:{config["port"]}/{config["service"]}'
    return oracledb.connect(user="system", password=config["sys_password"], dsn=dsn)


def get_hrms_connection(config):
    dsn = f'{config["host"]}:{config["port"]}/{config["service"]}'
    return oracledb.connect(
        user=config["hrms_user"], password=config["hrms_password"], dsn=dsn
    )


def setup_schema(config, reset=False):
    """Create the HRMS user/schema with necessary privileges."""
    print("=== Setting up HRMS schema ===")
    conn = get_sys_connection(config)
    cur = conn.cursor()

    if reset:
        print("  Dropping existing HRMS user...")
        try:
            cur.execute("DROP USER hrms CASCADE")
            print("  Dropped existing HRMS user.")
        except oracledb.DatabaseError:
            print("  No existing HRMS user to drop.")

    try:
        cur.execute(
            f'CREATE USER hrms IDENTIFIED BY {config["hrms_password"]} '
            "DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS"
        )
        print("  Created HRMS user.")
    except oracledb.DatabaseError as e:
        if "ORA-01920" in str(e):
            print("  HRMS user already exists.")
        else:
            raise

    grants = [
        "GRANT CONNECT, RESOURCE TO hrms",
        "GRANT CREATE SESSION TO hrms",
        "GRANT CREATE TABLE TO hrms",
        "GRANT CREATE VIEW TO hrms",
        "GRANT CREATE SEQUENCE TO hrms",
        "GRANT CREATE PROCEDURE TO hrms",
        "GRANT CREATE TRIGGER TO hrms",
        "GRANT CREATE TYPE TO hrms",
        "GRANT CREATE SYNONYM TO hrms",
        "GRANT EXECUTE ON DBMS_OUTPUT TO hrms",
        "GRANT EXECUTE ON DBMS_CRYPTO TO hrms",
    ]
    for g in grants:
        try:
            cur.execute(g)
        except oracledb.DatabaseError:
            pass

    conn.commit()
    conn.close()
    print("  Schema privileges granted.")

    # Grant DBMS_CRYPTO via SYSDBA in Docker (needed for PKG_SECURITY)
    grant_dbms_crypto_via_docker(config)


def grant_dbms_crypto_via_docker(config):
    """Grant DBMS_CRYPTO and related privileges via SYSDBA in Docker."""
    docker_container = os.environ.get("ORACLE_DOCKER_CONTAINER", "oracle-xe")
    service = config["service"]
    hrms_user = config["hrms_user"]
    sql_script = f"""ALTER SESSION SET CONTAINER = {service};
GRANT EXECUTE ON DBMS_CRYPTO TO {hrms_user};
GRANT EXECUTE ON UTL_SMTP TO {hrms_user};
GRANT EXECUTE ON UTL_TCP TO {hrms_user};
GRANT EXECUTE ON UTL_RAW TO {hrms_user};
EXIT;
"""
    try:
        result = subprocess.run(
            ["docker", "exec", "-i", docker_container, "sqlplus", "-s",
             "/ as sysdba"],
            input=sql_script, capture_output=True, text=True, timeout=30,
        )
        if "Grant succeeded" in result.stdout:
            print("  DBMS_CRYPTO and UTL_* privileges granted via SYSDBA.")
        else:
            print(f"  Note: SYSDBA grants output: {result.stdout.strip()[:200]}")
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"  Note: Could not grant via Docker SYSDBA: {e}")
        print("  DBMS_CRYPTO grant may need to be applied manually.")


def execute_sql_file(conn, filepath, schema_prefix="HRMS."):
    """Execute a SQL file, handling Oracle-specific syntax."""
    print(f"  Running: {os.path.basename(filepath)}")
    with open(filepath, "r") as f:
        content = f.read()

    # Remove SET DEFINE OFF and similar SQL*Plus commands
    lines = content.split("\n")
    filtered = []
    for line in lines:
        stripped = line.strip().upper()
        if stripped.startswith("SET ") or stripped.startswith("WHENEVER "):
            continue
        filtered.append(line)
    content = "\n".join(filtered)

    # Replace HRMS. schema prefix since we connect as HRMS user directly
    content = content.replace(schema_prefix, "")

    # Split on semicolons for regular statements, handle PL/SQL blocks with /
    statements = split_sql_statements(content)

    cur = conn.cursor()
    errors = []
    for stmt in statements:
        stmt = stmt.strip()
        if not stmt or stmt == "/":
            continue
        try:
            cur.execute(stmt)
        except oracledb.DatabaseError as e:
            error_msg = str(e)
            # Ignore "already exists" errors
            if "ORA-00955" in error_msg or "ORA-01430" in error_msg:
                pass
            else:
                errors.append((stmt[:80], error_msg.split("\n")[0]))

    conn.commit()
    return errors


def split_sql_statements(content):
    """Split SQL content into individual statements, handling PL/SQL blocks."""
    statements = []
    current = []
    in_plsql_block = False
    in_create_trigger = False
    in_create_or_replace = False

    for line in content.split("\n"):
        stripped = line.strip()
        upper = stripped.upper()

        # Detect PL/SQL block start
        if (
            upper.startswith("CREATE OR REPLACE TRIGGER")
            or upper.startswith("CREATE OR REPLACE PACKAGE")
            or upper.startswith("CREATE OR REPLACE FUNCTION")
            or upper.startswith("CREATE OR REPLACE PROCEDURE")
            or upper.startswith("CREATE TRIGGER")
        ):
            in_plsql_block = True
            current.append(line)
            continue

        if in_plsql_block:
            if stripped == "/":
                # End of PL/SQL block
                stmt = "\n".join(current)
                statements.append(stmt)
                current = []
                in_plsql_block = False
            else:
                current.append(line)
            continue

        # Regular SQL statement - split on semicolons
        if stripped.endswith(";"):
            current.append(line.rstrip().rstrip(";"))
            stmt = "\n".join(current)
            statements.append(stmt)
            current = []
        elif stripped == "COMMIT" or stripped == "COMMIT;":
            current.append("COMMIT")
            stmt = "\n".join(current)
            statements.append(stmt)
            current = []
        else:
            current.append(line)

    # Handle any remaining content
    if current:
        stmt = "\n".join(current).strip()
        if stmt and stmt != "/":
            statements.append(stmt)

    return statements


def run_ddl(config):
    """Run schema DDL scripts in order."""
    print("\n=== Running DDL scripts ===")
    conn = get_hrms_connection(config)

    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Order matters for foreign key dependencies
    ddl_files = [
        os.path.join(base, "schema", "sequences", "hrms_sequences.sql"),
        os.path.join(base, "schema", "tables", "01_core_tables.sql"),
        os.path.join(base, "schema", "tables", "02_payroll_tables.sql"),
        os.path.join(base, "schema", "tables", "03_leave_tables.sql"),
        os.path.join(base, "schema", "tables", "04_performance_tables.sql"),
    ]

    all_errors = []
    for f in ddl_files:
        if os.path.exists(f):
            errors = execute_sql_file(conn, f)
            all_errors.extend(errors)

    conn.close()
    return all_errors


def run_views(config):
    """Create database views."""
    print("\n=== Creating views ===")
    conn = get_hrms_connection(config)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    view_file = os.path.join(base, "schema", "views", "hrms_views.sql")
    errors = []
    if os.path.exists(view_file):
        errors = execute_sql_file(conn, view_file)
    conn.close()
    return errors


def compile_plsql_via_docker(config):
    """Compile PL/SQL via sqlplus in Docker for reliable multi-line handling."""
    print("\n=== Compiling PL/SQL packages ===")
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pkg_dir = os.path.join(base, "plsql", "packages")
    trg_dir = os.path.join(base, "plsql", "triggers")

    docker_container = os.environ.get("ORACLE_DOCKER_CONTAINER", "oracle-xe")

    spec_order = [
        "PKG_COMMON.pks", "PKG_AUDIT.pks", "PKG_VALIDATION.pks",
        "PKG_NOTIFICATION.pks", "PKG_SECURITY.pks", "PKG_EMPLOYEE.pks",
        "PKG_PAYROLL.pks", "PKG_LEAVE.pks", "PKG_PERFORMANCE.pks",
        "PKG_REPORTING.pks", "PKG_INTEGRATION.pks",
    ]
    body_order = [
        "PKG_COMMON.pkb", "PKG_AUDIT.pkb", "PKG_VALIDATION.pkb",
        "PKG_NOTIFICATION.pkb", "PKG_SECURITY.pkb", "PKG_EMPLOYEE.pkb",
        "PKG_PAYROLL.pkb", "PKG_LEAVE.pkb", "PKG_PERFORMANCE.pkb",
        "PKG_REPORTING.pkb", "PKG_INTEGRATION.pkb",
    ]

    # Copy all PL/SQL files to Docker container
    all_files = []
    print("  Copying PL/SQL files to Docker container...")
    for fname in spec_order + body_order:
        fpath = os.path.join(pkg_dir, fname)
        if os.path.exists(fpath):
            subprocess.run(
                ["docker", "cp", fpath, f"{docker_container}:/tmp/{fname}"],
                check=True, capture_output=True,
            )
            all_files.append(fname)

    trg_files = sorted(glob.glob(os.path.join(trg_dir, "*.sql")))
    for trg_file in trg_files:
        fname = os.path.basename(trg_file)
        subprocess.run(
            ["docker", "cp", trg_file, f"{docker_container}:/tmp/{fname}"],
            check=True, capture_output=True,
        )
        all_files.append(fname)

    # Build sqlplus script
    dsn = f'{config["hrms_user"]}/{config["hrms_password"]}@//localhost:1521/{config["service"]}'
    sql_lines = ["SET DEFINE OFF", "SET SERVEROUTPUT ON"]

    print("  Compiling package specifications...")
    for fname in spec_order:
        sql_lines.append(f"@/tmp/{fname}")

    print("  Compiling package bodies...")
    for fname in body_order:
        sql_lines.append(f"@/tmp/{fname}")

    print("  Compiling triggers...")
    for trg_file in trg_files:
        sql_lines.append(f"@/tmp/{os.path.basename(trg_file)}")

    sql_lines.append("EXIT;")
    sql_script = "\n".join(sql_lines)

    result = subprocess.run(
        ["docker", "exec", "-i", docker_container, "sqlplus", "-s", dsn],
        input=sql_script, capture_output=True, text=True, timeout=120,
    )

    if result.returncode != 0:
        print(f"  ERROR: sqlplus returned code {result.returncode}")
        print(f"  {result.stderr}")

    # Check output for errors
    output = result.stdout
    for line in output.split("\n"):
        if "compilation errors" in line.lower():
            print(f"  WARNING: {line.strip()}")

    return []


def load_seed_data(config):
    """Load seed/reference data."""
    print("\n=== Loading seed data ===")
    conn = get_hrms_connection(config)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    seed_files = [
        os.path.join(base, "data", "seed", "01_reference_data.sql"),
        os.path.join(base, "data", "seed", "02_employee_data.sql"),
    ]

    all_errors = []
    for f in seed_files:
        if os.path.exists(f):
            errors = execute_sql_file(conn, f)
            all_errors.extend(errors)

    conn.close()
    return all_errors


def verify_setup(config):
    """Verify the database setup is complete."""
    print("\n=== Verifying setup ===")
    conn = get_hrms_connection(config)
    cur = conn.cursor()

    checks = {
        "Tables": "SELECT COUNT(*) FROM user_tables",
        "Views": "SELECT COUNT(*) FROM user_views",
        "Sequences": "SELECT COUNT(*) FROM user_sequences",
        "Packages": "SELECT COUNT(*) FROM user_objects WHERE object_type = 'PACKAGE'",
        "Package Bodies": "SELECT COUNT(*) FROM user_objects WHERE object_type = 'PACKAGE BODY'",
        "Triggers": "SELECT COUNT(*) FROM user_objects WHERE object_type = 'TRIGGER'",
        "Invalid Objects": (
            "SELECT COUNT(*) FROM user_objects WHERE status = 'INVALID'"
        ),
    }

    print(f"  {'Object Type':<20} {'Count':>8}")
    print(f"  {'-'*20} {'-'*8}")

    results = {}
    for name, query in checks.items():
        cur.execute(query)
        count = cur.fetchone()[0]
        results[name] = count
        print(f"  {name:<20} {count:>8}")

    # Check row counts for key tables
    print(f"\n  {'Table':<30} {'Rows':>8}")
    print(f"  {'-'*30} {'-'*8}")

    tables_to_check = [
        "DEPARTMENTS",
        "LOCATIONS",
        "JOB_GRADES",
        "JOB_TITLES",
        "EMPLOYEES",
        "SALARY_RECORDS",
        "LEAVE_TYPES",
        "PAY_ELEMENTS",
        "HOLIDAYS",
        "SYSTEM_PARAMETERS",
    ]

    for table in tables_to_check:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            count = cur.fetchone()[0]
            print(f"  {table:<30} {count:>8}")
        except oracledb.DatabaseError:
            print(f"  {table:<30} {'N/A':>8}")

    # List invalid objects
    if results.get("Invalid Objects", 0) > 0:
        print("\n  Invalid objects:")
        cur.execute(
            "SELECT object_type, object_name FROM user_objects "
            "WHERE status = 'INVALID' ORDER BY object_type, object_name"
        )
        for row in cur:
            print(f"    {row[0]}: {row[1]}")

    conn.close()
    return results


def main():
    parser = argparse.ArgumentParser(description="HRMS Database Setup")
    parser.add_argument(
        "--reset", action="store_true", help="Drop and recreate the HRMS schema"
    )
    args = parser.parse_args()

    config = get_config()
    all_errors = []

    try:
        # Step 1: Create schema
        setup_schema(config, reset=args.reset)

        # Step 2: Run DDL
        errors = run_ddl(config)
        all_errors.extend(errors)

        # Step 3: Create views
        errors = run_views(config)
        all_errors.extend(errors)

        # Step 4: Compile PL/SQL (via sqlplus in Docker for reliable handling)
        errors = compile_plsql_via_docker(config)
        all_errors.extend(errors)

        # Step 5: Load seed data
        errors = load_seed_data(config)
        all_errors.extend(errors)

        # Step 6: Verify
        results = verify_setup(config)

        # Summary
        print("\n=== Setup Summary ===")
        if all_errors:
            print(f"  Warnings/Errors: {len(all_errors)}")
            for stmt, err in all_errors[:10]:
                print(f"    {stmt}...")
                print(f"      -> {err}")
            if len(all_errors) > 10:
                print(f"    ... and {len(all_errors) - 10} more")

        invalid_count = results.get("Invalid Objects", 0)
        if invalid_count > 0:
            print(f"\n  WARNING: {invalid_count} invalid object(s) detected.")
            print("  Run: SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID';")

        table_count = results.get("Tables", 0)
        pkg_count = results.get("Packages", 0)
        if table_count > 0 and pkg_count > 0:
            print("\n  Database setup completed successfully.")
            return 0
        else:
            print("\n  ERROR: Setup may be incomplete.")
            return 1

    except Exception as e:
        print(f"\nFATAL ERROR: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
