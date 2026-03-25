# Oracle WebCenter User Provisioning Script

A Python script to bulk-create users in Oracle WebCenter from a CSV file. Supports three WebCenter API backends:

| API Type | Description | Use Case |
|----------|-------------|----------|
| `portal` | WebCenter Portal REST API | Managing portal community users |
| `content` | WebCenter Content (UCM) RIDC/REST | Managing content repository users |
| `idcs`   | Oracle Identity Cloud Service (SCIM) | Cloud-based identity management |

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Copy and edit the config file
cp config.example.json config.json
# Edit config.json with your WebCenter URL and credentials

# 3. Prepare your CSV (see sample_users.csv for format)

# 4. Run the script
python webcenter_user_provisioning.py --config config.json --csv users.csv
```

## CSV Format

**Required columns:** `user_id`, `first_name`, `last_name`, `email`

**Optional columns:** `display_name`, `department`, `role`, `title`, `manager`, `phone`, `organization`, `locale`, `timezone`, `password`

Example:

```csv
user_id,first_name,last_name,email,display_name,department,role,title
jsmith,John,Smith,john.smith@example.com,John Smith,Engineering,contributor,Software Engineer
adoe,Alice,Doe,alice.doe@example.com,Alice Doe,HR,admin,HR Manager
```

If `display_name` is not provided, it defaults to `first_name + last_name`.

## Configuration

Configuration can be provided in three ways (highest priority wins):

1. **Environment variables** (highest priority):
   - `WEBCENTER_BASE_URL`
   - `WEBCENTER_USERNAME`
   - `WEBCENTER_PASSWORD`
   - `WEBCENTER_IDCS_CLIENT_ID`
   - `WEBCENTER_IDCS_CLIENT_SECRET`

2. **CLI arguments**:
   ```bash
   python webcenter_user_provisioning.py \
       --csv users.csv \
       --base-url https://webcenter.example.com \
       --username admin \
       --password secret \
       --api-type portal
   ```

3. **JSON config file** (lowest priority):
   ```bash
   python webcenter_user_provisioning.py --config config.json --csv users.csv
   ```

### Config File Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `base_url` | string | *(required)* | WebCenter server base URL |
| `username` | string | *(required for portal/content)* | Admin username |
| `password` | string | | Admin password |
| `api_type` | string | `portal` | API backend: `portal`, `content`, or `idcs` |
| `timeout` | int | `30` | HTTP request timeout in seconds |
| `verify_ssl` | bool | `true` | Verify SSL certificates |
| `idcs_client_id` | string | | OAuth client ID (IDCS only) |
| `idcs_client_secret` | string | | OAuth client secret (IDCS only) |
| `default_role` | string | | Default role for users without a role in the CSV |
| `default_password` | string | | Default password for users without a password in the CSV |

## CLI Options

```
usage: webcenter_user_provisioning.py [-h] --csv CSV [--config CONFIG]
                                       [--base-url BASE_URL]
                                       [--username USERNAME]
                                       [--password PASSWORD]
                                       [--api-type {portal,content,idcs}]
                                       [--dry-run] [--no-verify-ssl]
                                       [--report REPORT] [--log-file LOG_FILE]
                                       [--verbose]

Options:
  --csv CSV             Path to the CSV file containing user details (required)
  --config CONFIG       Path to a JSON configuration file
  --base-url BASE_URL   WebCenter base URL
  --username USERNAME   Admin username
  --password PASSWORD   Admin password
  --api-type TYPE       API type: portal, content, or idcs
  --dry-run             Simulate provisioning without making API calls
  --no-verify-ssl       Disable SSL certificate verification
  --report PATH         Path to write JSON report (default: provisioning_report.json)
  --log-file PATH       Path to a log file (in addition to console output)
  --verbose             Enable debug logging
```

## Usage Examples

### Dry Run (test without making API calls)

```bash
python webcenter_user_provisioning.py \
    --config config.json \
    --csv users.csv \
    --dry-run
```

### WebCenter Portal

```bash
python webcenter_user_provisioning.py \
    --csv users.csv \
    --base-url https://webcenter.example.com \
    --username admin \
    --password secret \
    --api-type portal
```

### WebCenter Content (UCM)

```bash
python webcenter_user_provisioning.py \
    --csv users.csv \
    --base-url https://ucm.example.com/cs \
    --username admin \
    --password secret \
    --api-type content
```

### Oracle IDCS

```bash
export WEBCENTER_IDCS_CLIENT_ID=your-client-id
export WEBCENTER_IDCS_CLIENT_SECRET=your-client-secret

python webcenter_user_provisioning.py \
    --csv users.csv \
    --base-url https://idcs-xxxxx.identity.oraclecloud.com \
    --api-type idcs
```

### With Logging and Custom Report

```bash
python webcenter_user_provisioning.py \
    --config config.json \
    --csv users.csv \
    --verbose \
    --log-file provisioning.log \
    --report results.json
```

## Output

### Console Output

The script logs progress to the console:

```
2024-01-15 10:30:00 [INFO] Oracle WebCenter User Provisioning Script
2024-01-15 10:30:00 [INFO] Target URL  : https://webcenter.example.com
2024-01-15 10:30:00 [INFO] Parsed 5 valid user record(s) from users.csv
2024-01-15 10:30:00 [INFO] Processing user 1/5: jsmith
2024-01-15 10:30:01 [INFO] Created user: jsmith (john.smith@example.com)
...
2024-01-15 10:30:05 [INFO] ============================================================
2024-01-15 10:30:05 [INFO] PROVISIONING SUMMARY
2024-01-15 10:30:05 [INFO] ============================================================
2024-01-15 10:30:05 [INFO] Total processed : 5
2024-01-15 10:30:05 [INFO] Created         : 5
2024-01-15 10:30:05 [INFO] Failed          : 0
```

### JSON Report

A detailed JSON report is written to `provisioning_report.json` (or the path specified with `--report`):

```json
{
  "run_timestamp": "2024-01-15T10:30:05.123456",
  "total": 5,
  "created": 5,
  "failed": 0,
  "skipped": 0,
  "results": [
    {
      "user_id": "jsmith",
      "success": true,
      "message": "User created successfully",
      "http_status": 201,
      "timestamp": "2024-01-15T10:30:01.234567"
    }
  ]
}
```

## Error Handling

- **Missing required CSV columns**: Script exits with an error message listing missing columns.
- **Empty required fields in a row**: Row is skipped with a warning, other rows are still processed.
- **HTTP 409 (Conflict)**: User already exists — logged as a warning, marked as failed in the report.
- **Network errors**: Automatic retry (3 attempts with exponential backoff) for transient failures (HTTP 429, 500, 502, 503, 504).
- **Authentication failures**: Logged and reported; script continues processing remaining users.

## Security Notes

- Prefer environment variables over CLI arguments for passwords (CLI args may be visible in process listings).
- The `config.example.json` file is a template — do not commit `config.json` with real credentials.
- Use `--no-verify-ssl` only in development environments.
