#!/usr/bin/env python3
"""
HRMS Database Validation Tests
Validates that the Oracle database setup is complete and correct.

Usage:
    python3 scripts/validate_setup.py

Environment variables:
    ORACLE_HOST     - Database host (default: localhost)
    ORACLE_PORT     - Database port (default: 1521)
    ORACLE_SERVICE  - Service name (default: XEPDB1)
    HRMS_USER       - HRMS schema user (required)
    HRMS_PASSWORD   - HRMS schema password (required)
"""

import os
import sys

import oracledb


def get_connection():
    host = os.environ.get("ORACLE_HOST", "localhost")
    port = int(os.environ.get("ORACLE_PORT", "1521"))
    service = os.environ.get("ORACLE_SERVICE", "XEPDB1")
    user = os.environ.get("HRMS_USER", "")
    password = os.environ.get("HRMS_PASSWORD", "")
    if not user or not password:
        print("ERROR: HRMS_USER and HRMS_PASSWORD env vars are required.")
        sys.exit(1)
    dsn = f"{host}:{port}/{service}"
    return oracledb.connect(user=user, password=password, dsn=dsn)


class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []

    def ok(self, name):
        self.passed += 1
        print(f"  PASS: {name}")

    def fail(self, name, detail=""):
        self.failed += 1
        msg = f"  FAIL: {name}"
        if detail:
            msg += f" -- {detail}"
        self.errors.append(msg)
        print(msg)

    @property
    def total(self):
        return self.passed + self.failed


def test_schema_objects(cur, result):
    """Validate expected schema object counts."""
    print("\n--- Schema Object Counts ---")

    expectations = {
        "TABLE": (30, "Tables"),
        "VIEW": (6, "Views"),
        "SEQUENCE": (29, "Sequences"),
        "PACKAGE": (11, "Package specifications"),
        "PACKAGE BODY": (11, "Package bodies"),
        "TRIGGER": (6, "Triggers"),
    }

    for obj_type, (expected, label) in expectations.items():
        cur.execute(
            "SELECT COUNT(*) FROM user_objects WHERE object_type = :t",
            [obj_type],
        )
        actual = cur.fetchone()[0]
        if actual >= expected:
            result.ok(f"{label}: {actual} (expected >= {expected})")
        else:
            result.fail(f"{label}: {actual} (expected >= {expected})")


def test_no_invalid_objects(cur, result):
    """Validate no invalid PL/SQL objects exist."""
    print("\n--- Invalid Objects ---")

    cur.execute(
        "SELECT object_type, object_name FROM user_objects "
        "WHERE status = 'INVALID' ORDER BY object_type, object_name"
    )
    invalid = cur.fetchall()

    if len(invalid) == 0:
        result.ok("No invalid objects")
    else:
        for obj_type, obj_name in invalid:
            result.fail(f"Invalid object: {obj_type} {obj_name}")


def test_seed_data(cur, result):
    """Validate seed data was loaded into key tables."""
    print("\n--- Seed Data Row Counts ---")

    expected_rows = {
        "DEPARTMENTS": 10,
        "LOCATIONS": 3,
        "JOB_GRADES": 10,
        "JOB_TITLES": 25,
        "EMPLOYEES": 20,
        "SALARY_RECORDS": 20,
        "LEAVE_TYPES": 6,
        "PAY_ELEMENTS": 11,
        "HOLIDAYS": 10,
        "SYSTEM_PARAMETERS": 10,
    }

    for table, min_rows in expected_rows.items():
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            actual = cur.fetchone()[0]
            if actual >= min_rows:
                result.ok(f"{table}: {actual} rows (expected >= {min_rows})")
            else:
                result.fail(
                    f"{table}: {actual} rows (expected >= {min_rows})"
                )
        except oracledb.DatabaseError as e:
            result.fail(f"{table}: query failed", str(e).split("\n")[0])


def test_package_validity(cur, result):
    """Validate all expected packages exist and are valid."""
    print("\n--- Package Validation ---")

    expected_packages = [
        "PKG_COMMON", "PKG_AUDIT", "PKG_VALIDATION",
        "PKG_NOTIFICATION", "PKG_SECURITY", "PKG_EMPLOYEE",
        "PKG_PAYROLL", "PKG_LEAVE", "PKG_PERFORMANCE",
        "PKG_REPORTING", "PKG_INTEGRATION",
    ]

    for pkg in expected_packages:
        cur.execute(
            "SELECT status FROM user_objects "
            "WHERE object_type = 'PACKAGE BODY' AND object_name = :n",
            [pkg],
        )
        row = cur.fetchone()
        if row is None:
            result.fail(f"Package body {pkg}: NOT FOUND")
        elif row[0] == "VALID":
            result.ok(f"Package body {pkg}: VALID")
        else:
            result.fail(f"Package body {pkg}: {row[0]}")


def test_views_queryable(cur, result):
    """Validate views can be queried without errors."""
    print("\n--- View Validation ---")

    cur.execute("SELECT view_name FROM user_views ORDER BY view_name")
    views = [row[0] for row in cur.fetchall()]

    for view in views:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {view}")
            count = cur.fetchone()[0]
            result.ok(f"View {view}: queryable ({count} rows)")
        except oracledb.DatabaseError as e:
            result.fail(f"View {view}: query failed", str(e).split("\n")[0])


def test_sequences_exist(cur, result):
    """Validate key sequences exist."""
    print("\n--- Sequence Validation ---")

    expected_sequences = [
        "SEQ_EMPLOYEE", "SEQ_DEPARTMENT", "SEQ_SALARY",
        "SEQ_LEAVE_REQUEST", "SEQ_PAYROLL_RUN",
    ]

    for seq in expected_sequences:
        cur.execute(
            "SELECT COUNT(*) FROM user_sequences WHERE sequence_name = :n",
            [seq],
        )
        if cur.fetchone()[0] > 0:
            result.ok(f"Sequence {seq}: exists")
        else:
            result.fail(f"Sequence {seq}: NOT FOUND")


def test_triggers_enabled(cur, result):
    """Validate triggers are enabled."""
    print("\n--- Trigger Validation ---")

    cur.execute(
        "SELECT trigger_name, status FROM user_triggers "
        "ORDER BY trigger_name"
    )
    triggers = cur.fetchall()

    for name, status in triggers:
        if status == "ENABLED":
            result.ok(f"Trigger {name}: ENABLED")
        else:
            result.fail(f"Trigger {name}: {status}")


def main():
    print("=" * 60)
    print("HRMS Database Validation Tests")
    print("=" * 60)

    try:
        conn = get_connection()
    except oracledb.DatabaseError as e:
        print(f"\nFATAL: Cannot connect to database: {e}")
        return 1

    cur = conn.cursor()
    result = TestResult()

    test_schema_objects(cur, result)
    test_no_invalid_objects(cur, result)
    test_seed_data(cur, result)
    test_package_validity(cur, result)
    test_views_queryable(cur, result)
    test_sequences_exist(cur, result)
    test_triggers_enabled(cur, result)

    conn.close()

    print("\n" + "=" * 60)
    print(f"Results: {result.passed} passed, {result.failed} failed "
          f"(out of {result.total} tests)")
    print("=" * 60)

    if result.failed > 0:
        print("\nFailed tests:")
        for err in result.errors:
            print(f"  {err}")
        return 1

    print("\nAll tests passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
