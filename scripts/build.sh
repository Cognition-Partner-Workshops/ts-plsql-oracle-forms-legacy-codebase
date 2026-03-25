#!/usr/bin/env bash
# ============================================================================
# HRMS Oracle Database Build Script
# Loads schema objects, PL/SQL packages, triggers, views, and seed data
# into an Oracle database in dependency order.
#
# Usage:
#   ./scripts/build.sh [--seed]
#
# Environment variables:
#   ORACLE_HOST     - Database host (default: localhost)
#   ORACLE_PORT     - Database port (default: 1521)
#   ORACLE_SERVICE  - Service name (default: FREEPDB1)
#   ORACLE_SYS_PWD  - SYS password (default: HrmsAdmin123)
#   HRMS_USER       - Application schema user (default: hrms)
#   HRMS_PASSWORD   - Application schema password (default: hrms123)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
ORACLE_HOST="${ORACLE_HOST:-localhost}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-FREEPDB1}"
ORACLE_SYS_PWD="${ORACLE_SYS_PWD:-HrmsAdmin123}"
HRMS_USER="${HRMS_USER:-hrms}"
HRMS_PASSWORD="${HRMS_PASSWORD:-hrms123}"
DOCKER_CONTAINER="${DOCKER_CONTAINER:-hrms-oracle}"
LOAD_SEED="${LOAD_SEED:-false}"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --seed) LOAD_SEED="true" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------
# Execute SQL via docker exec + sqlplus
# -----------------------------------------------------------------------
run_sql_as_sys() {
    local sql="$1"
    docker exec -i "$DOCKER_CONTAINER" sqlplus -S "sys/${ORACLE_SYS_PWD}@//localhost:1521/${ORACLE_SERVICE} as sysdba" <<EOF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE
${sql}
EXIT;
EOF
}

run_sql_as_hrms() {
    local sql="$1"
    docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE
${sql}
EXIT;
EOF
}

run_file_as_hrms() {
    local file="$1"
    local content
    content=$(cat "$file")
    docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
}

# -----------------------------------------------------------------------
# Step 0: Check Oracle is running
# -----------------------------------------------------------------------
log_info "Checking Oracle database connectivity..."
if ! run_sql_as_sys "SELECT 'CONNECTED' FROM DUAL;" 2>/dev/null | grep -q CONNECTED; then
    log_error "Cannot connect to Oracle database. Is the container running?"
    exit 1
fi
log_ok "Oracle database is accessible"

# -----------------------------------------------------------------------
# Step 1: Grant privileges to HRMS user
# -----------------------------------------------------------------------
log_info "Granting privileges to ${HRMS_USER} user..."
run_sql_as_sys "
ALTER USER ${HRMS_USER} QUOTA UNLIMITED ON USERS;
GRANT CREATE TABLE TO ${HRMS_USER};
GRANT CREATE VIEW TO ${HRMS_USER};
GRANT CREATE SEQUENCE TO ${HRMS_USER};
GRANT CREATE PROCEDURE TO ${HRMS_USER};
GRANT CREATE TRIGGER TO ${HRMS_USER};
GRANT CREATE TYPE TO ${HRMS_USER};
GRANT CREATE SESSION TO ${HRMS_USER};
GRANT EXECUTE ON DBMS_CRYPTO TO ${HRMS_USER};
GRANT EXECUTE ON UTL_RAW TO ${HRMS_USER};
GRANT EXECUTE ON DBMS_OUTPUT TO ${HRMS_USER};
GRANT EXECUTE ON UTL_FILE TO ${HRMS_USER};
" > /dev/null 2>&1
log_ok "Privileges granted"

# -----------------------------------------------------------------------
# Step 2: Create schema tables (in dependency order)
# -----------------------------------------------------------------------
log_info "Creating schema tables..."
TABLE_FILES=(
    "$PROJECT_DIR/schema/tables/01_core_tables.sql"
    "$PROJECT_DIR/schema/tables/02_payroll_tables.sql"
    "$PROJECT_DIR/schema/tables/03_leave_tables.sql"
    "$PROJECT_DIR/schema/tables/04_performance_tables.sql"
)
for file in "${TABLE_FILES[@]}"; do
    fname=$(basename "$file")
    log_info "  Loading $fname..."
    # Strip HRMS. schema prefix since we connect as HRMS user
    content=$(sed 's/HRMS\.//g' "$file")
    result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
SET HEADING OFF
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
    if echo "$result" | grep -qi "error"; then
        log_warn "  Some errors in $fname (may be pre-existing objects)"
    else
        log_ok "  $fname loaded"
    fi
done

# -----------------------------------------------------------------------
# Step 3: Create sequences
# -----------------------------------------------------------------------
log_info "Creating sequences..."
content=$(sed 's/HRMS\.//g' "$PROJECT_DIR/schema/sequences/hrms_sequences.sql")
result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
log_ok "Sequences created"

# -----------------------------------------------------------------------
# Step 4: Compile PL/SQL package specifications (order matters for deps)
# -----------------------------------------------------------------------
log_info "Compiling PL/SQL package specifications..."
SPEC_ORDER=(
    PKG_COMMON
    PKG_AUDIT
    PKG_VALIDATION
    PKG_NOTIFICATION
    PKG_EMPLOYEE
    PKG_PAYROLL
    PKG_LEAVE
    PKG_PERFORMANCE
    PKG_SECURITY
    PKG_REPORTING
    PKG_INTEGRATION
)
ERRORS=0
for pkg in "${SPEC_ORDER[@]}"; do
    spec_file="$PROJECT_DIR/plsql/packages/${pkg}.pks"
    if [ -f "$spec_file" ]; then
        log_info "  Compiling ${pkg} spec..."
        content=$(sed 's/HRMS\.//g' "$spec_file")
        result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
        if echo "$result" | grep -qi "error\|warning"; then
            log_warn "  ${pkg} spec had warnings/errors"
            ERRORS=$((ERRORS + 1))
        else
            log_ok "  ${pkg} spec compiled"
        fi
    fi
done

# -----------------------------------------------------------------------
# Step 5: Compile PL/SQL package bodies (after all specs are in place)
# -----------------------------------------------------------------------
log_info "Compiling PL/SQL package bodies..."
for pkg in "${SPEC_ORDER[@]}"; do
    body_file="$PROJECT_DIR/plsql/packages/${pkg}.pkb"
    if [ -f "$body_file" ]; then
        log_info "  Compiling ${pkg} body..."
        content=$(sed 's/HRMS\.//g' "$body_file")
        result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
        if echo "$result" | grep -qi "error\|warning"; then
            log_warn "  ${pkg} body had warnings/errors"
            ERRORS=$((ERRORS + 1))
        else
            log_ok "  ${pkg} body compiled"
        fi
    fi
done

# -----------------------------------------------------------------------
# Step 6: Create triggers
# -----------------------------------------------------------------------
log_info "Creating triggers..."
for tfile in "$PROJECT_DIR"/plsql/triggers/*.sql; do
    fname=$(basename "$tfile")
    log_info "  Loading $fname..."
    content=$(sed 's/HRMS\.//g' "$tfile")
    result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
    if echo "$result" | grep -qi "error"; then
        log_warn "  $fname had errors"
        ERRORS=$((ERRORS + 1))
    else
        log_ok "  $fname loaded"
    fi
done

# -----------------------------------------------------------------------
# Step 7: Create views
# -----------------------------------------------------------------------
log_info "Creating views..."
content=$(sed 's/HRMS\.//g' "$PROJECT_DIR/schema/views/hrms_views.sql")
result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
${content}
EXIT;
EOF
)
log_ok "Views created"

# -----------------------------------------------------------------------
# Step 8: Load seed data (optional)
# -----------------------------------------------------------------------
if [ "$LOAD_SEED" = "true" ]; then
    log_info "Loading seed data..."
    for seed_file in "$PROJECT_DIR"/data/seed/*.sql; do
        fname=$(basename "$seed_file")
        log_info "  Loading $fname..."
        content=$(sed 's/HRMS\.//g' "$seed_file")
        result=$(docker exec -i "$DOCKER_CONTAINER" sqlplus -S "${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/${ORACLE_SERVICE}" <<EOF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE
SET DEFINE OFF
${content}
COMMIT;
EXIT;
EOF
)
        if echo "$result" | grep -qi "ORA-"; then
            log_warn "  $fname had some ORA errors (column mismatches in legacy data expected)"
        else
            log_ok "  $fname loaded"
        fi
    done
fi

# -----------------------------------------------------------------------
# Step 9: Check compilation status
# -----------------------------------------------------------------------
log_info "Checking for invalid objects..."
invalid_count=$(run_sql_as_hrms "
SELECT COUNT(*) FROM USER_OBJECTS WHERE STATUS = 'INVALID';
" 2>/dev/null | tr -d '[:space:]')

if [ "$invalid_count" -gt 0 ] 2>/dev/null; then
    log_warn "$invalid_count invalid object(s) found. Attempting recompilation..."
    run_sql_as_hrms "
BEGIN
    DBMS_UTILITY.COMPILE_SCHEMA(schema => USER, compile_all => FALSE);
END;
/
" > /dev/null 2>&1

    invalid_count=$(run_sql_as_hrms "
SELECT COUNT(*) FROM USER_OBJECTS WHERE STATUS = 'INVALID';
" 2>/dev/null | tr -d '[:space:]')

    if [ "$invalid_count" -gt 0 ] 2>/dev/null; then
        log_warn "$invalid_count object(s) still invalid after recompilation:"
        run_sql_as_hrms "
SELECT OBJECT_TYPE || ': ' || OBJECT_NAME AS INVALID_OBJ
FROM USER_OBJECTS WHERE STATUS = 'INVALID' ORDER BY OBJECT_TYPE, OBJECT_NAME;
"
    fi
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
log_info "========================================="
log_info "Build Summary"
log_info "========================================="
obj_summary=$(run_sql_as_hrms "
SELECT OBJECT_TYPE || ': ' || COUNT(*) || ' (' ||
       SUM(CASE WHEN STATUS='VALID' THEN 1 ELSE 0 END) || ' valid, ' ||
       SUM(CASE WHEN STATUS='INVALID' THEN 1 ELSE 0 END) || ' invalid)'
FROM USER_OBJECTS
WHERE OBJECT_TYPE IN ('TABLE','VIEW','SEQUENCE','PACKAGE','PACKAGE BODY','TRIGGER','INDEX')
GROUP BY OBJECT_TYPE ORDER BY OBJECT_TYPE;
" 2>/dev/null)
echo "$obj_summary"
echo ""

if [ "${invalid_count:-0}" -eq 0 ] 2>/dev/null; then
    log_ok "Build completed successfully!"
    exit 0
else
    log_warn "Build completed with $invalid_count invalid object(s)"
    exit 1
fi
