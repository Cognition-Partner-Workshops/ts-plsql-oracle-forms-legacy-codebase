#!/usr/bin/env bash
# ============================================================================
# HRMS Database Validation Script
# Verifies that all schema objects are valid and data is consistent
#
# Usage: ./scripts/validate.sh
# ============================================================================

set -euo pipefail

ORACLE_SYS_PWD="${ORACLE_SYS_PWD:-HrmsAdmin123}"
HRMS_USER="${HRMS_USER:-hrms}"
HRMS_PASSWORD="${HRMS_PASSWORD:-hrms123}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-hrms-oracle}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[PASS]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_fail()  { echo -e "${RED}[FAIL]${NC}  $1"; }

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1"
    local sql="$2"
    local expected="${3:-}"

    result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/FREEPDB1" <<EOF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 200
SET TRIMOUT ON
SET TRIMSPOOL ON
${sql}
EXIT;
EOF
)
    result=$(echo "$result" | tr -d '[:space:]')

    if [ -n "$expected" ]; then
        if [ "$result" = "$expected" ]; then
            log_ok "$desc (got: $result)"
            PASS=$((PASS + 1))
        else
            log_fail "$desc (expected: $expected, got: $result)"
            FAIL=$((FAIL + 1))
        fi
    else
        # Just display the result
        log_info "$desc: $result"
    fi
}

echo "============================================"
echo "  HRMS Database Validation"
echo "============================================"
echo ""

# -----------------------------------------------------------------------
# 1. Object existence checks
# -----------------------------------------------------------------------
log_info "--- Schema Object Checks ---"

check "Tables exist (expected 26+)" \
    "SELECT COUNT(*) FROM USER_TABLES;" ""

check "No invalid objects" \
    "SELECT COUNT(*) FROM USER_OBJECTS WHERE STATUS = 'INVALID';" "0"

check "Sequences exist" \
    "SELECT COUNT(*) FROM USER_SEQUENCES;" ""

check "Views exist" \
    "SELECT COUNT(*) FROM USER_VIEWS;" ""

check "Package specs compiled" \
    "SELECT COUNT(*) FROM USER_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE' AND STATUS = 'VALID';" ""

check "Package bodies compiled" \
    "SELECT COUNT(*) FROM USER_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE BODY' AND STATUS = 'VALID';" ""

check "Triggers compiled" \
    "SELECT COUNT(*) FROM USER_OBJECTS WHERE OBJECT_TYPE = 'TRIGGER' AND STATUS = 'VALID';" ""

echo ""
log_info "--- Core Table Checks ---"

check "DEPARTMENTS table exists" \
    "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'DEPARTMENTS';" "1"

check "EMPLOYEES table exists" \
    "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'EMPLOYEES';" "1"

check "SALARY_RECORDS table exists" \
    "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'SALARY_RECORDS';" "1"

check "LEAVE_REQUESTS table exists" \
    "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'LEAVE_REQUESTS';" "1"

check "PERFORMANCE_REVIEWS table exists" \
    "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'PERFORMANCE_REVIEWS';" "1"

echo ""
log_info "--- Package Compilation Checks ---"

for pkg in PKG_COMMON PKG_AUDIT PKG_VALIDATION PKG_NOTIFICATION PKG_EMPLOYEE PKG_PAYROLL PKG_LEAVE PKG_PERFORMANCE PKG_SECURITY PKG_REPORTING PKG_INTEGRATION; do
    check "${pkg} spec valid" \
        "SELECT STATUS FROM USER_OBJECTS WHERE OBJECT_NAME = '${pkg}' AND OBJECT_TYPE = 'PACKAGE';" "VALID"
done

echo ""
log_info "--- Package Body Compilation Checks ---"

for pkg in PKG_COMMON PKG_AUDIT PKG_INTEGRATION; do
    check "${pkg} body valid" \
        "SELECT STATUS FROM USER_OBJECTS WHERE OBJECT_NAME = '${pkg}' AND OBJECT_TYPE = 'PACKAGE BODY';" "VALID"
done

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Validation Summary"
echo "============================================"
echo -e "  ${GREEN}Passed:${NC}  $PASS"
echo -e "  ${RED}Failed:${NC}  $FAIL"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo ""

if [ "$FAIL" -gt 0 ]; then
    log_fail "Validation completed with $FAIL failure(s)"
    exit 1
else
    log_ok "All validations passed!"
    exit 0
fi
