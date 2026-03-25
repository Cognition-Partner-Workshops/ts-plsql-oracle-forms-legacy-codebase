#!/usr/bin/env python3
"""
Oracle WebCenter User Provisioning Script

Reads user details from a CSV file and creates users in Oracle WebCenter
via its REST API. Supports both WebCenter Portal and WebCenter Content
user provisioning.

Usage:
    python webcenter_user_provisioning.py --config config.json --csv users.csv
    python webcenter_user_provisioning.py --csv users.csv \
        --base-url https://webcenter.example.com \
        --username admin --password secret
"""

import argparse
import csv
import json
import logging
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
DEFAULT_TIMEOUT = 30  # seconds
MAX_RETRIES = 3
RETRY_BACKOFF_FACTOR = 0.5
RETRY_STATUS_CODES = (429, 500, 502, 503, 504)

REQUIRED_CSV_COLUMNS = {"user_id", "first_name", "last_name", "email"}
OPTIONAL_CSV_COLUMNS = {
    "display_name",
    "department",
    "role",
    "title",
    "manager",
    "phone",
    "organization",
    "locale",
    "timezone",
    "password",
}

# WebCenter REST API endpoints
WC_PORTAL_USERS_ENDPOINT = "/rest/api/people"
WC_CONTENT_ACCOUNTS_ENDPOINT = "/idcplg?IdcService=ADD_USER"
WC_IDCS_USERS_ENDPOINT = "/admin/v1/Users"

LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------
@dataclass
class WebCenterConfig:
    """Configuration for WebCenter connection."""

    base_url: str = ""
    username: str = ""
    password: str = ""
    api_type: str = "portal"  # portal | content | idcs
    timeout: int = DEFAULT_TIMEOUT
    verify_ssl: bool = True
    idcs_client_id: str = ""
    idcs_client_secret: str = ""
    default_role: str = ""
    default_password: str = ""
    dry_run: bool = False


@dataclass
class UserRecord:
    """Represents a single user to be provisioned."""

    user_id: str
    first_name: str
    last_name: str
    email: str
    display_name: str = ""
    department: str = ""
    role: str = ""
    title: str = ""
    manager: str = ""
    phone: str = ""
    organization: str = ""
    locale: str = ""
    timezone: str = ""
    password: str = ""


@dataclass
class ProvisioningResult:
    """Result of a single user provisioning attempt."""

    user_id: str
    success: bool
    message: str
    http_status: Optional[int] = None
    timestamp: str = ""

    def __post_init__(self) -> None:
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()


@dataclass
class ProvisioningSummary:
    """Summary of the entire provisioning run."""

    total: int = 0
    created: int = 0
    failed: int = 0
    skipped: int = 0
    results: list = field(default_factory=list)

    def add_result(self, result: ProvisioningResult) -> None:
        self.results.append(result)
        self.total += 1
        if result.success:
            self.created += 1
        else:
            self.failed += 1


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
def setup_logging(log_file: Optional[str] = None, verbose: bool = False) -> logging.Logger:
    """Configure logging to console and optionally to a file."""
    logger = logging.getLogger("webcenter_provisioning")
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    console_handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=LOG_DATE_FORMAT))
    logger.addHandler(console_handler)

    if log_file:
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=LOG_DATE_FORMAT))
        logger.addHandler(file_handler)

    return logger


# ---------------------------------------------------------------------------
# HTTP Session
# ---------------------------------------------------------------------------
def create_http_session(config: WebCenterConfig) -> requests.Session:
    """Create a requests session with retry logic and authentication."""
    session = requests.Session()

    retry_strategy = Retry(
        total=MAX_RETRIES,
        backoff_factor=RETRY_BACKOFF_FACTOR,
        status_forcelist=RETRY_STATUS_CODES,
        allowed_methods=["GET", "POST", "PUT"],
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    session.verify = config.verify_ssl
    session.headers.update({
        "Content-Type": "application/json",
        "Accept": "application/json",
    })

    if config.api_type == "idcs" and config.idcs_client_id:
        token = _get_idcs_token(config)
        session.headers["Authorization"] = f"Bearer {token}"
    else:
        session.auth = (config.username, config.password)

    return session


def _get_idcs_token(config: WebCenterConfig) -> str:
    """Obtain an OAuth2 token from Oracle IDCS for API access."""
    token_url = urljoin(config.base_url, "/oauth2/v1/token")
    response = requests.post(
        token_url,
        data={"grant_type": "client_credentials", "scope": "urn:opc:idm:__myscopes__"},
        auth=(config.idcs_client_id, config.idcs_client_secret),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        timeout=config.timeout,
        verify=config.verify_ssl,
    )
    response.raise_for_status()
    return response.json()["access_token"]


# ---------------------------------------------------------------------------
# CSV Parsing
# ---------------------------------------------------------------------------
def parse_csv(csv_path: str, logger: logging.Logger) -> list[UserRecord]:
    """Parse a CSV file and return a list of UserRecord objects."""
    csv_file = Path(csv_path)
    if not csv_file.exists():
        logger.error("CSV file not found: %s", csv_path)
        sys.exit(1)

    users: list[UserRecord] = []
    with open(csv_file, newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)

        if reader.fieldnames is None:
            logger.error("CSV file is empty or has no header row.")
            sys.exit(1)

        columns = {col.strip().lower() for col in reader.fieldnames}
        missing = REQUIRED_CSV_COLUMNS - columns
        if missing:
            logger.error("CSV is missing required columns: %s", ", ".join(sorted(missing)))
            sys.exit(1)

        for row_num, row in enumerate(reader, start=2):
            # Normalize keys to lowercase/stripped
            normalized = {k.strip().lower(): v.strip() for k, v in row.items() if k}

            # Validate required fields are non-empty
            empty_required = [
                col for col in REQUIRED_CSV_COLUMNS if not normalized.get(col)
            ]
            if empty_required:
                logger.warning(
                    "Row %d: skipping — empty required field(s): %s",
                    row_num,
                    ", ".join(sorted(empty_required)),
                )
                continue

            user = UserRecord(
                user_id=normalized["user_id"],
                first_name=normalized["first_name"],
                last_name=normalized["last_name"],
                email=normalized["email"],
                display_name=normalized.get("display_name", ""),
                department=normalized.get("department", ""),
                role=normalized.get("role", ""),
                title=normalized.get("title", ""),
                manager=normalized.get("manager", ""),
                phone=normalized.get("phone", ""),
                organization=normalized.get("organization", ""),
                locale=normalized.get("locale", ""),
                timezone=normalized.get("timezone", ""),
                password=normalized.get("password", ""),
            )
            if not user.display_name:
                user.display_name = f"{user.first_name} {user.last_name}"
            users.append(user)

    logger.info("Parsed %d valid user record(s) from %s", len(users), csv_path)
    return users


# ---------------------------------------------------------------------------
# User creation — WebCenter Portal REST API
# ---------------------------------------------------------------------------
def _build_portal_payload(user: UserRecord, config: WebCenterConfig) -> dict:
    """Build the JSON payload for WebCenter Portal user creation."""
    payload: dict = {
        "login": user.user_id,
        "displayName": user.display_name,
        "firstName": user.first_name,
        "lastName": user.last_name,
        "mail": user.email,
    }
    if user.department:
        payload["department"] = user.department
    if user.title:
        payload["title"] = user.title
    if user.phone:
        payload["telephoneNumber"] = user.phone
    if user.organization:
        payload["organization"] = user.organization
    if user.manager:
        payload["manager"] = user.manager
    if user.role or config.default_role:
        payload["role"] = user.role or config.default_role
    if user.locale:
        payload["preferredLanguage"] = user.locale
    if user.timezone:
        payload["timeZone"] = user.timezone
    if user.password or config.default_password:
        payload["password"] = user.password or config.default_password
    return payload


def create_user_portal(
    session: requests.Session,
    user: UserRecord,
    config: WebCenterConfig,
    logger: logging.Logger,
) -> ProvisioningResult:
    """Create a user via WebCenter Portal REST API."""
    url = urljoin(config.base_url.rstrip("/") + "/", WC_PORTAL_USERS_ENDPOINT.lstrip("/"))
    payload = _build_portal_payload(user, config)

    logger.debug("POST %s — payload: %s", url, json.dumps(payload, indent=2))

    if config.dry_run:
        logger.info("[DRY RUN] Would create user: %s (%s)", user.user_id, user.email)
        return ProvisioningResult(user_id=user.user_id, success=True, message="Dry run — skipped")

    try:
        response = session.post(url, json=payload, timeout=config.timeout)
        if response.status_code in (200, 201):
            logger.info("Created user: %s (%s)", user.user_id, user.email)
            return ProvisioningResult(
                user_id=user.user_id,
                success=True,
                message="User created successfully",
                http_status=response.status_code,
            )
        elif response.status_code == 409:
            logger.warning("User already exists: %s", user.user_id)
            return ProvisioningResult(
                user_id=user.user_id,
                success=False,
                message="User already exists (HTTP 409)",
                http_status=409,
            )
        else:
            error_body = response.text[:500]
            logger.error(
                "Failed to create user %s — HTTP %d: %s",
                user.user_id,
                response.status_code,
                error_body,
            )
            return ProvisioningResult(
                user_id=user.user_id,
                success=False,
                message=f"HTTP {response.status_code}: {error_body}",
                http_status=response.status_code,
            )
    except requests.RequestException as exc:
        logger.error("Request error for user %s: %s", user.user_id, exc)
        return ProvisioningResult(
            user_id=user.user_id, success=False, message=f"Request error: {exc}"
        )


# ---------------------------------------------------------------------------
# User creation — WebCenter Content (UCM)
# ---------------------------------------------------------------------------
def _build_content_payload(user: UserRecord, config: WebCenterConfig) -> dict:
    """Build the payload for WebCenter Content (UCM) user creation."""
    payload: dict = {
        "IdcService": "ADD_USER",
        "dName": user.user_id,
        "dUserAuthType": "LOCAL",
        "dFullName": user.display_name,
        "dEmail": user.email,
    }
    if user.role or config.default_role:
        payload["dUserRoles"] = user.role or config.default_role
    if user.locale:
        payload["dUserLocale"] = user.locale
    if user.timezone:
        payload["dUserTimeZone"] = user.timezone
    if user.password or config.default_password:
        payload["dPassword"] = user.password or config.default_password
    return payload


def create_user_content(
    session: requests.Session,
    user: UserRecord,
    config: WebCenterConfig,
    logger: logging.Logger,
) -> ProvisioningResult:
    """Create a user via WebCenter Content (UCM) RIDC/REST interface."""
    url = urljoin(config.base_url.rstrip("/") + "/", WC_CONTENT_ACCOUNTS_ENDPOINT.lstrip("/"))
    payload = _build_content_payload(user, config)

    logger.debug("POST %s — payload: %s", url, json.dumps(payload, indent=2))

    if config.dry_run:
        logger.info("[DRY RUN] Would create user: %s (%s)", user.user_id, user.email)
        return ProvisioningResult(user_id=user.user_id, success=True, message="Dry run — skipped")

    try:
        response = session.post(url, data=payload, timeout=config.timeout)
        if response.status_code in (200, 201):
            # UCM returns 200 even for some errors; check response body
            body = response.text
            if "UserAlreadyExists" in body or "already exists" in body.lower():
                logger.warning("User already exists in Content: %s", user.user_id)
                return ProvisioningResult(
                    user_id=user.user_id,
                    success=False,
                    message="User already exists in WebCenter Content",
                    http_status=200,
                )
            logger.info("Created user in Content: %s (%s)", user.user_id, user.email)
            return ProvisioningResult(
                user_id=user.user_id,
                success=True,
                message="User created in WebCenter Content",
                http_status=response.status_code,
            )
        else:
            error_body = response.text[:500]
            logger.error(
                "Failed to create Content user %s — HTTP %d: %s",
                user.user_id,
                response.status_code,
                error_body,
            )
            return ProvisioningResult(
                user_id=user.user_id,
                success=False,
                message=f"HTTP {response.status_code}: {error_body}",
                http_status=response.status_code,
            )
    except requests.RequestException as exc:
        logger.error("Request error for Content user %s: %s", user.user_id, exc)
        return ProvisioningResult(
            user_id=user.user_id, success=False, message=f"Request error: {exc}"
        )


# ---------------------------------------------------------------------------
# User creation — Oracle IDCS (Identity Cloud Service)
# ---------------------------------------------------------------------------
def _build_idcs_payload(user: UserRecord, config: WebCenterConfig) -> dict:
    """Build the SCIM payload for Oracle IDCS user creation."""
    payload: dict = {
        "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
        "userName": user.user_id,
        "name": {
            "givenName": user.first_name,
            "familyName": user.last_name,
            "formatted": user.display_name,
        },
        "displayName": user.display_name,
        "emails": [{"value": user.email, "type": "work", "primary": True}],
        "active": True,
    }
    if user.phone:
        payload["phoneNumbers"] = [{"value": user.phone, "type": "work"}]
    if user.title:
        payload["title"] = user.title
    if user.department or user.organization or user.manager:
        enterprise_ext: dict = {}
        if user.department:
            enterprise_ext["department"] = user.department
        if user.organization:
            enterprise_ext["organization"] = user.organization
        if user.manager:
            enterprise_ext["manager"] = {"value": user.manager}
        payload["urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"] = enterprise_ext
        payload["schemas"].append(
            "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
        )
    if user.locale:
        payload["locale"] = user.locale
    if user.timezone:
        payload["timezone"] = user.timezone
    if user.password or config.default_password:
        payload["password"] = user.password or config.default_password
    return payload


def create_user_idcs(
    session: requests.Session,
    user: UserRecord,
    config: WebCenterConfig,
    logger: logging.Logger,
) -> ProvisioningResult:
    """Create a user via Oracle IDCS SCIM API."""
    url = urljoin(config.base_url.rstrip("/") + "/", WC_IDCS_USERS_ENDPOINT.lstrip("/"))
    payload = _build_idcs_payload(user, config)

    logger.debug("POST %s — payload: %s", url, json.dumps(payload, indent=2))

    if config.dry_run:
        logger.info("[DRY RUN] Would create IDCS user: %s (%s)", user.user_id, user.email)
        return ProvisioningResult(user_id=user.user_id, success=True, message="Dry run — skipped")

    try:
        response = session.post(url, json=payload, timeout=config.timeout)
        if response.status_code in (200, 201):
            logger.info("Created IDCS user: %s (%s)", user.user_id, user.email)
            return ProvisioningResult(
                user_id=user.user_id,
                success=True,
                message="User created in IDCS",
                http_status=response.status_code,
            )
        elif response.status_code == 409:
            logger.warning("IDCS user already exists: %s", user.user_id)
            return ProvisioningResult(
                user_id=user.user_id,
                success=False,
                message="User already exists in IDCS (HTTP 409)",
                http_status=409,
            )
        else:
            error_body = response.text[:500]
            logger.error(
                "Failed to create IDCS user %s — HTTP %d: %s",
                user.user_id,
                response.status_code,
                error_body,
            )
            return ProvisioningResult(
                user_id=user.user_id,
                success=False,
                message=f"HTTP {response.status_code}: {error_body}",
                http_status=response.status_code,
            )
    except requests.RequestException as exc:
        logger.error("Request error for IDCS user %s: %s", user.user_id, exc)
        return ProvisioningResult(
            user_id=user.user_id, success=False, message=f"Request error: {exc}"
        )


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------
API_TYPE_HANDLERS = {
    "portal": create_user_portal,
    "content": create_user_content,
    "idcs": create_user_idcs,
}


def provision_users(
    users: list[UserRecord],
    config: WebCenterConfig,
    logger: logging.Logger,
) -> ProvisioningSummary:
    """Provision all users using the configured API type."""
    handler = API_TYPE_HANDLERS.get(config.api_type)
    if handler is None:
        logger.error(
            "Unknown api_type '%s'. Supported types: %s",
            config.api_type,
            ", ".join(API_TYPE_HANDLERS.keys()),
        )
        sys.exit(1)

    session = create_http_session(config)
    summary = ProvisioningSummary()

    logger.info(
        "Starting provisioning — %d user(s), api_type=%s, target=%s",
        len(users),
        config.api_type,
        config.base_url,
    )

    for idx, user in enumerate(users, start=1):
        logger.info("Processing user %d/%d: %s", idx, len(users), user.user_id)
        result = handler(session, user, config, logger)
        summary.add_result(result)

        # Rate-limit courtesy pause between requests
        if idx < len(users):
            time.sleep(0.2)

    session.close()
    return summary


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
def write_report(summary: ProvisioningSummary, report_path: str, logger: logging.Logger) -> None:
    """Write a JSON report of the provisioning results."""
    report = {
        "run_timestamp": datetime.utcnow().isoformat(),
        "total": summary.total,
        "created": summary.created,
        "failed": summary.failed,
        "skipped": summary.skipped,
        "results": [
            {
                "user_id": r.user_id,
                "success": r.success,
                "message": r.message,
                "http_status": r.http_status,
                "timestamp": r.timestamp,
            }
            for r in summary.results
        ],
    }
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, ensure_ascii=False)
    logger.info("Report written to %s", report_path)


def print_summary(summary: ProvisioningSummary, logger: logging.Logger) -> None:
    """Print a human-readable summary to the log."""
    logger.info("=" * 60)
    logger.info("PROVISIONING SUMMARY")
    logger.info("=" * 60)
    logger.info("Total processed : %d", summary.total)
    logger.info("Created         : %d", summary.created)
    logger.info("Failed          : %d", summary.failed)
    logger.info("Skipped         : %d", summary.skipped)
    logger.info("=" * 60)

    if summary.failed > 0:
        logger.info("Failed users:")
        for r in summary.results:
            if not r.success:
                logger.info("  - %s : %s", r.user_id, r.message)


# ---------------------------------------------------------------------------
# Configuration loading
# ---------------------------------------------------------------------------
def load_config(args: argparse.Namespace) -> WebCenterConfig:
    """Build a WebCenterConfig from CLI args and optional config file."""
    config = WebCenterConfig()

    # Load from config file first (if provided)
    if args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"Error: config file not found: {args.config}", file=sys.stderr)
            sys.exit(1)
        with open(config_path, encoding="utf-8") as fh:
            cfg = json.load(fh)
        config.base_url = cfg.get("base_url", config.base_url)
        config.username = cfg.get("username", config.username)
        config.password = cfg.get("password", config.password)
        config.api_type = cfg.get("api_type", config.api_type)
        config.timeout = cfg.get("timeout", config.timeout)
        config.verify_ssl = cfg.get("verify_ssl", config.verify_ssl)
        config.idcs_client_id = cfg.get("idcs_client_id", config.idcs_client_id)
        config.idcs_client_secret = cfg.get("idcs_client_secret", config.idcs_client_secret)
        config.default_role = cfg.get("default_role", config.default_role)
        config.default_password = cfg.get("default_password", config.default_password)

    # CLI args override config file values
    if args.base_url:
        config.base_url = args.base_url
    if args.username:
        config.username = args.username
    if args.password:
        config.password = args.password
    if args.api_type:
        config.api_type = args.api_type
    if args.no_verify_ssl:
        config.verify_ssl = False
    if args.dry_run:
        config.dry_run = True

    # Environment variable overrides (highest priority)
    config.base_url = os.environ.get("WEBCENTER_BASE_URL", config.base_url)
    config.username = os.environ.get("WEBCENTER_USERNAME", config.username)
    config.password = os.environ.get("WEBCENTER_PASSWORD", config.password)
    config.idcs_client_id = os.environ.get("WEBCENTER_IDCS_CLIENT_ID", config.idcs_client_id)
    config.idcs_client_secret = os.environ.get(
        "WEBCENTER_IDCS_CLIENT_SECRET", config.idcs_client_secret
    )

    # Validate required fields
    if not config.base_url:
        print(
            "Error: base_url is required. Provide via --base-url, config file, "
            "or WEBCENTER_BASE_URL env var.",
            file=sys.stderr,
        )
        sys.exit(1)
    if not config.username and config.api_type != "idcs":
        print(
            "Error: username is required. Provide via --username, config file, "
            "or WEBCENTER_USERNAME env var.",
            file=sys.stderr,
        )
        sys.exit(1)

    return config


# ---------------------------------------------------------------------------
# CLI Argument Parser
# ---------------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    """Build the command-line argument parser."""
    parser = argparse.ArgumentParser(
        description="Provision users in Oracle WebCenter from a CSV file.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Using a config file
  python webcenter_user_provisioning.py --config config.json --csv users.csv

  # Using CLI arguments
  python webcenter_user_provisioning.py \\
      --csv users.csv \\
      --base-url https://webcenter.example.com \\
      --username admin \\
      --password secret \\
      --api-type portal

  # Dry run (no actual API calls)
  python webcenter_user_provisioning.py --config config.json --csv users.csv --dry-run

  # Using environment variables
  export WEBCENTER_BASE_URL=https://webcenter.example.com
  export WEBCENTER_USERNAME=admin
  export WEBCENTER_PASSWORD=secret
  python webcenter_user_provisioning.py --csv users.csv

CSV Format:
  Required columns: user_id, first_name, last_name, email
  Optional columns: display_name, department, role, title, manager,
                    phone, organization, locale, timezone, password
        """,
    )

    parser.add_argument(
        "--csv",
        required=True,
        help="Path to the CSV file containing user details",
    )
    parser.add_argument(
        "--config",
        help="Path to a JSON configuration file",
    )
    parser.add_argument(
        "--base-url",
        help="WebCenter base URL (e.g. https://webcenter.example.com)",
    )
    parser.add_argument(
        "--username",
        help="Admin username for WebCenter authentication",
    )
    parser.add_argument(
        "--password",
        help="Admin password for WebCenter authentication",
    )
    parser.add_argument(
        "--api-type",
        choices=["portal", "content", "idcs"],
        help="WebCenter API type: portal (default), content (UCM), or idcs",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate provisioning without making API calls",
    )
    parser.add_argument(
        "--no-verify-ssl",
        action="store_true",
        help="Disable SSL certificate verification",
    )
    parser.add_argument(
        "--report",
        help="Path to write a JSON report of results (default: provisioning_report.json)",
        default="provisioning_report.json",
    )
    parser.add_argument(
        "--log-file",
        help="Path to a log file (in addition to console output)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose/debug logging",
    )

    return parser


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    """Main entry point."""
    parser = build_parser()
    args = parser.parse_args()

    # Set up logging
    logger = setup_logging(log_file=args.log_file, verbose=args.verbose)
    logger.info("Oracle WebCenter User Provisioning Script")
    logger.info("-" * 50)

    # Load configuration
    config = load_config(args)
    logger.info("Target URL  : %s", config.base_url)
    logger.info("API Type    : %s", config.api_type)
    logger.info("Dry Run     : %s", config.dry_run)
    logger.info("SSL Verify  : %s", config.verify_ssl)

    # Parse CSV
    users = parse_csv(args.csv, logger)
    if not users:
        logger.warning("No valid users found in CSV. Exiting.")
        sys.exit(0)

    # Provision users
    summary = provision_users(users, config, logger)

    # Print summary and write report
    print_summary(summary, logger)
    write_report(summary, args.report, logger)

    # Exit with non-zero code if any failures
    if summary.failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
