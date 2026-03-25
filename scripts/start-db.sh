#!/usr/bin/env bash
# ============================================================================
# Start Oracle Free 23ai Docker container for local HRMS development
#
# Usage: ./scripts/start-db.sh
#
# Environment variables:
#   ORACLE_SYS_PWD  - SYS password (default: HrmsAdmin123)
#   HRMS_USER       - Application user (default: hrms)
#   HRMS_PASSWORD   - Application password (default: hrms123)
# ============================================================================

set -euo pipefail

ORACLE_SYS_PWD="${ORACLE_SYS_PWD:-HrmsAdmin123}"
HRMS_USER="${HRMS_USER:-hrms}"
HRMS_PASSWORD="${HRMS_PASSWORD:-hrms123}"
CONTAINER_NAME="hrms-oracle"
IMAGE="gvenzl/oracle-free:23-slim"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_ok "Container '${CONTAINER_NAME}' is already running"
        exit 0
    else
        log_info "Starting existing container '${CONTAINER_NAME}'..."
        docker start "$CONTAINER_NAME"
    fi
else
    log_info "Pulling Oracle Free image (if needed)..."
    docker pull "$IMAGE" 2>/dev/null || true

    log_info "Creating container '${CONTAINER_NAME}'..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p 1521:1521 \
        -e ORACLE_PASSWORD="$ORACLE_SYS_PWD" \
        -e APP_USER="$HRMS_USER" \
        -e APP_USER_PASSWORD="$HRMS_PASSWORD" \
        "$IMAGE"
fi

# Wait for database to be ready
log_info "Waiting for Oracle database to start (this may take 1-2 minutes)..."
MAX_ATTEMPTS=60
for i in $(seq 1 $MAX_ATTEMPTS); do
    if docker exec "$CONTAINER_NAME" sqlplus -S "sys/${ORACLE_SYS_PWD}@//localhost:1521/FREEPDB1 as sysdba" <<< "SELECT 'READY' FROM DUAL;" 2>/dev/null | grep -q READY; then
        log_ok "Oracle database is ready!"
        echo ""
        echo "  Connection details:"
        echo "    Host:     localhost"
        echo "    Port:     1521"
        echo "    Service:  FREEPDB1"
        echo "    SYS pwd:  ${ORACLE_SYS_PWD}"
        echo "    App user: ${HRMS_USER}/${HRMS_PASSWORD}"
        echo ""
        echo "  Connect as SYS:  docker exec -it ${CONTAINER_NAME} sqlplus sys/${ORACLE_SYS_PWD}@//localhost:1521/FREEPDB1 as sysdba"
        echo "  Connect as HRMS: docker exec -it ${CONTAINER_NAME} sqlplus ${HRMS_USER}/${HRMS_PASSWORD}@//localhost:1521/FREEPDB1"
        exit 0
    fi
    printf "."
    sleep 3
done

echo ""
log_error "Oracle did not become ready within $((MAX_ATTEMPTS * 3)) seconds"
log_error "Check logs with: docker logs ${CONTAINER_NAME}"
exit 1
