# HRMS Oracle Forms Legacy Codebase - Build & Setup
# Requires: Docker, Python 3.x, oracledb Python package

DOCKER_IMAGE    ?= gvenzl/oracle-xe:21-slim
DOCKER_NAME     ?= oracle-xe
ORACLE_PORT     ?= 1521
ORACLE_SYS_PWD  ?= $(error Set ORACLE_SYS_PWD env var)
ORACLE_SERVICE  ?= XEPDB1
HRMS_USER       ?= $(error Set HRMS_USER env var)
HRMS_PASSWORD   ?= $(error Set HRMS_PASSWORD env var)

.PHONY: help deps db-start db-stop db-status setup reset test validate clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

deps: ## Install Python dependencies
	pip install oracledb

db-start: ## Start Oracle XE Docker container
	@if docker ps -q -f name=$(DOCKER_NAME) | grep -q .; then \
		echo "Oracle XE container already running."; \
	else \
		echo "Starting Oracle XE container..."; \
		docker run -d --name $(DOCKER_NAME) \
			-p $(ORACLE_PORT):1521 \
			-e ORACLE_PASSWORD=$(ORACLE_SYS_PWD) \
			$(DOCKER_IMAGE); \
		echo "Waiting for Oracle XE to be ready (this may take 30-60 seconds)..."; \
		until docker exec $(DOCKER_NAME) sqlplus -s system/$(ORACLE_SYS_PWD)@//localhost:1521/$(ORACLE_SERVICE) \
			<<< "SELECT 1 FROM dual; EXIT;" 2>/dev/null | grep -q "1"; do \
			sleep 5; \
			echo "  Still waiting..."; \
		done; \
		echo "Oracle XE is ready."; \
	fi

db-stop: ## Stop Oracle XE Docker container
	docker stop $(DOCKER_NAME) 2>/dev/null || true
	docker rm $(DOCKER_NAME) 2>/dev/null || true

db-status: ## Check Oracle XE container status
	@docker ps -f name=$(DOCKER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@python3 -c "import oracledb; \
		conn = oracledb.connect(user='$(HRMS_USER)', password='$(HRMS_PASSWORD)', \
		dsn='localhost:$(ORACLE_PORT)/$(ORACLE_SERVICE)'); \
		cur = conn.cursor(); \
		cur.execute('SELECT COUNT(*) FROM user_tables'); \
		print(f'Connected to HRMS schema: {cur.fetchone()[0]} tables'); \
		conn.close()" 2>/dev/null || echo "Cannot connect to HRMS schema."

setup: db-start ## Run full database setup (schema, DDL, PL/SQL, seed data)
	ORACLE_SYS_PWD=$(ORACLE_SYS_PWD) ORACLE_SERVICE=$(ORACLE_SERVICE) \
	HRMS_USER=$(HRMS_USER) HRMS_PASSWORD=$(HRMS_PASSWORD) \
	ORACLE_DOCKER_CONTAINER=$(DOCKER_NAME) \
		python3 scripts/setup_database.py

reset: db-start ## Drop and recreate HRMS schema from scratch
	ORACLE_SYS_PWD=$(ORACLE_SYS_PWD) ORACLE_SERVICE=$(ORACLE_SERVICE) \
	HRMS_USER=$(HRMS_USER) HRMS_PASSWORD=$(HRMS_PASSWORD) \
	ORACLE_DOCKER_CONTAINER=$(DOCKER_NAME) \
		python3 scripts/setup_database.py --reset

test: ## Run validation tests against the database
	ORACLE_SERVICE=$(ORACLE_SERVICE) \
	HRMS_USER=$(HRMS_USER) HRMS_PASSWORD=$(HRMS_PASSWORD) \
		python3 scripts/validate_setup.py

validate: test ## Alias for test

clean: db-stop ## Stop and remove Oracle XE container
	@echo "Cleaned up Oracle XE container."
