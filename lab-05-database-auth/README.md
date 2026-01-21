# Lab 05: Database Authentication with Kerberos

**Status:** ✅ Active  
**Difficulty:** Advanced  
**Prerequisites:** Understanding of Kerberos and basic PostgreSQL (Lab 01 recommended)  
**Duration:** 45-60 minutes

## Overview

Secure database connections using Kerberos authentication with PostgreSQL. This lab demonstrates how to eliminate database passwords by leveraging Kerberos tickets for authentication, providing stronger security and centralized access control.

## What You'll Learn

- Configuring PostgreSQL for GSSAPI/Kerberos authentication
- Creating and deploying database service principals
- Managing PostgreSQL keytabs
- Client configuration for passwordless database access
- Python integration with psycopg2 and Kerberos
- Understanding pg_hba.conf for Kerberos rules
- GSSAPI encryption for database connections
- Transaction management with Kerberos

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│     KDC     │◄────────┤  PostgreSQL │◄────────┤   Client    │
│             │ Validates│   Server    │   SQL   │             │
│ kdc.example │  Tickets│postgres.ex..│  GSSAPI │client.ex... │
│    .com     │         │    .com     │   Auth  │    .com     │
└─────────────┘         └─────────────┘         └─────────────┘
      ▲                       │                       │
      │                       │                       │
      └───────────────────────┴───────────────────────┘
    Service Ticket: postgres/postgres.example.com
```

## Components

- **KDC Container**: Issues tickets for users and database service
- **PostgreSQL Server**: PostgreSQL 15 with GSSAPI authentication enabled
- **Client Container**: Pre-configured with psql and Python psycopg2
- **Service Principal**: `postgres/postgres.example.com@EXAMPLE.COM`
- **Sample Database**: Pre-populated testdb with demo schema

## Quick Start

### 1. Setup

```bash
# Run the automated setup script
./setup.sh
```

This script will:
- Start all containers
- Create the PostgreSQL service principal
- Generate and deploy the database keytab
- Configure PostgreSQL for GSSAPI authentication
- Initialize sample database with test data
- Create a database user principal
- Set up the client with psql and Python

### 2. Test Passwordless Database Access

```bash
# Enter the client container
docker exec -it db-client bash

# Obtain a Kerberos ticket
kinit dbuser@EXAMPLE.COM
# Password: dbpass123

# Verify your ticket
klist

# Connect to PostgreSQL - NO PASSWORD NEEDED!
psql -h postgres.example.com -U dbuser -d testdb

# You're now connected to PostgreSQL!
# Run some queries:
testdb=> SELECT * FROM demo.employees;
testdb=> SELECT * FROM demo.departments;
testdb=> \dt demo.*  -- List tables

# Exit
testdb=> \q
```

### 3. Test with Python

```bash
# Inside the client container
python3 /client-examples/connect.py

# Test data operations
python3 /client-examples/operations.py
```

## Understanding PostgreSQL Kerberos Authentication

### Authentication Flow

1. **Client has TGT** → User obtains initial ticket with `kinit`
2. **Database connection request** → Client initiates connection to PostgreSQL
3. **GSSAPI negotiation** → PostgreSQL requests Kerberos authentication
4. **Service ticket request** → Client requests `postgres/postgres.example.com` ticket from KDC
5. **Ticket presentation** → Client presents service ticket to PostgreSQL
6. **Server validation** → PostgreSQL validates ticket using its keytab
7. **Connection established** → User authenticated without password

### Service Principal

PostgreSQL uses the principal format:
```
postgres/<hostname>@<REALM>
```

For this lab: `postgres/postgres.example.com@EXAMPLE.COM`

The server's keytab (`/etc/keytabs/postgres.keytab`) contains the cryptographic keys needed to validate tickets.

## Configuration Details

### PostgreSQL Configuration (postgresql.conf)

Key settings for Kerberos:

```ini
# Kerberos keytab location
krb_server_keyfile = '/etc/keytabs/postgres.keytab'

# Case-insensitive username matching
krb_caseins_users = on
```

### Client Authentication (pg_hba.conf)

```
# TYPE  DATABASE   USER    ADDRESS          METHOD
hostgssenc  all    all     172.26.0.0/24    gss include_realm=0 krb_realm=EXAMPLE.COM
host        all    all     172.26.0.0/24    gss include_realm=0 krb_realm=EXAMPLE.COM
```

**Explanation:**
- `hostgssenc`: Requires GSSAPI encryption
- `host`: Allows GSSAPI with or without encryption
- `include_realm=0`: Strip @REALM from username
- `krb_realm=EXAMPLE.COM`: Only accept tickets from this realm

## Testing Scenarios

### Test 1: Basic psql Connection

```bash
# Get ticket
kinit dbuser@EXAMPLE.COM

# Connect (no -W for password!)
psql -h postgres.example.com -U dbuser -d testdb

# Verify connection
SELECT current_user, current_database();
```

### Test 2: Verify Service Ticket

```bash
# After connecting, check ticket cache
klist

# You should see:
# - krbtgt/EXAMPLE.COM@EXAMPLE.COM (TGT)
# - postgres/postgres.example.com@EXAMPLE.COM (Service ticket)
```

### Test 3: Python Connection

```python
import psycopg2

# No password parameter needed!
conn = psycopg2.connect(
    host="postgres.example.com",
    port=5432,
    database="testdb",
    user="dbuser",
    gssencmode="prefer"  # Use GSSAPI encryption
)

cursor = conn.cursor()
cursor.execute("SELECT version();")
print(cursor.fetchone()[0])
```

### Test 4: Without Valid Ticket

```bash
# Destroy ticket
kdestroy

# Try to connect
psql -h postgres.example.com -U dbuser -d testdb

# Should fail with authentication error
```

### Test 5: Data Manipulation

```bash
# Get ticket
kinit dbuser@EXAMPLE.COM

# Connect and perform operations
psql -h postgres.example.com -U dbuser -d testdb << EOF
-- Insert
INSERT INTO demo.employees (name, email, department)
VALUES ('New Employee', 'new@example.com', 'Engineering');

-- Update
UPDATE demo.projects SET status = 'completed' WHERE name = 'Security Audit';

-- Query with JOIN
SELECT e.name, e.department, d.location
FROM demo.employees e
JOIN demo.departments d ON e.department = d.name
ORDER BY e.name;
EOF
```

## Automated Testing

Run the comprehensive test suite:

```bash
docker exec -it db-client /test-scripts/test-db-auth.sh
```

Tests include:
- ✓ PostgreSQL server connectivity
- ✓ Kerberos ticket acquisition
- ✓ GSSAPI database authentication
- ✓ Service ticket validation
- ✓ Data queries (SELECT)
- ✓ Data manipulation (INSERT, UPDATE)
- ✓ Transaction handling
- ✓ Access control without ticket
- ✓ Python psycopg2 integration
- ✓ Concurrent connections

## Sample Database Schema

The lab includes a pre-populated database:

```sql
-- Schema: demo
-- Tables:
--   - employees (id, name, email, department, hire_date)
--   - departments (id, name, location, budget)
--   - projects (id, name, description, start_date, end_date, status)
--   - employee_summary (VIEW)

-- Sample data included for testing
```

### Example Queries

```sql
-- List all employees with department location
SELECT * FROM demo.employee_summary;

-- Department budgets
SELECT name, budget FROM demo.departments ORDER BY budget DESC;

-- Active projects
SELECT name, start_date FROM demo.projects WHERE status = 'active';

-- Employee count by department
SELECT department, COUNT(*) as emp_count
FROM demo.employees
GROUP BY department
ORDER BY emp_count DESC;
```

## Python Integration

### Using psycopg2

```python
import psycopg2

def connect_kerberos():
    conn = psycopg2.connect(
        host="postgres.example.com",
        database="testdb",
        user="dbuser",
        gssencmode="prefer"  # GSSAPI encryption
    )
    return conn

# Usage
conn = connect_kerberos()
cursor = conn.cursor()
cursor.execute("SELECT * FROM demo.employees")
for row in cursor.fetchall():
    print(row)
```

### Connection Pool

```python
from psycopg2 import pool

# Create connection pool (requires valid Kerberos ticket)
connection_pool = pool.SimpleConnectionPool(
    1, 10,  # min, max connections
    host="postgres.example.com",
    database="testdb",
    user="dbuser",
    gssencmode="prefer"
)

conn = connection_pool.getconn()
# Use connection...
connection_pool.putconn(conn)
```

## Troubleshooting

### Connection Fails with Authentication Error

```bash
# Check if you have a valid ticket
klist

# Verify ticket is not expired
kinit dbuser@EXAMPLE.COM

# Test connectivity
pg_isready -h postgres.example.com -p 5432
```

### Service Ticket Not Obtained

```bash
# Check KDC logs
docker logs kerberos-kdc-lab05

# Verify service principal exists
docker exec kerberos-kdc-lab05 kadmin.local -q "listprincs" | grep postgres/

# Check server keytab
docker exec postgres-kerberos klist -k /etc/keytabs/postgres.keytab
```

### PostgreSQL Configuration Issues

```bash
# Check PostgreSQL logs
docker logs postgres-kerberos

# Verify keytab path in config
docker exec postgres-kerberos psql -U postgres -c "SHOW krb_server_keyfile;"

# Check pg_hba.conf rules
docker exec postgres-kerberos cat /var/lib/postgresql/data/pg_hba.conf | grep gss
```

### Python Connection Errors

```bash
# Ensure psycopg2 is installed
pip3 install psycopg2-binary

# Check if ticket exists before running Python
klist

# Enable verbose output
PGSSLMODE=disable python3 -c "
import psycopg2
psycopg2.connect(
    host='postgres.example.com',
    database='testdb',
    user='dbuser',
    gssencmode='require'
)
"
```

### GSSAPI Encryption Not Working

```bash
# Check if PostgreSQL supports GSSAPI
docker exec postgres-kerberos psql -U postgres -c "SHOW gssencmode;"

# Verify in pg_hba.conf
# Use 'hostgssenc' instead of 'host' to require encryption

# Test connection with encryption required
psql "host=postgres.example.com dbname=testdb user=dbuser gssencmode=require"
```

## Key Files

- [docker-compose.yml](docker-compose.yml) - Container orchestration
- [Dockerfile.postgres](Dockerfile.postgres) - PostgreSQL with Kerberos
- [krb5.conf](krb5.conf) - Kerberos client configuration
- [postgres-config/postgresql.conf](postgres-config/postgresql.conf) - PostgreSQL server config
- [postgres-config/pg_hba.conf](postgres-config/pg_hba.conf) - Authentication rules
- [sql-init/01-init.sql](sql-init/01-init.sql) - Database initialization
- [client-examples/connect.py](client-examples/connect.py) - Python connection example
- [client-examples/operations.py](client-examples/operations.py) - Data operations example
- [setup.sh](setup.sh) - Automated setup script
- [test-scripts/test-db-auth.sh](test-scripts/test-db-auth.sh) - Automated tests
- [.env.example](.env.example) - Configuration template

## Environment Variables

Copy `.env.example` to `.env`:

```bash
REALM=EXAMPLE.COM                      # Kerberos realm
KDC_PASSWORD=Password123                # KDC admin password
POSTGRES_PORT=5432                      # External PostgreSQL port
POSTGRES_ADMIN_PASSWORD=AdminPass123    # postgres superuser password
DB_USER=dbuser@EXAMPLE.COM             # Database user principal
DB_PASSWORD=dbpass123                   # User password (for kinit)
DB_NAME=testdb                          # Database name
```

## Cleanup

```bash
# Stop and remove all containers and volumes
./cleanup.sh

# Or manually
docker-compose down -v
rm -rf keytabs
```

## Security Best Practices

### In Production

1. **Keytab Protection**
   ```bash
   chown postgres:postgres /etc/keytabs/postgres.keytab
   chmod 400 /etc/keytabs/postgres.keytab
   ```

2. **Require GSSAPI Encryption**
   ```
   # In pg_hba.conf
   hostgssenc  all  all  0.0.0.0/0  gss
   ```

3. **Disable Password Authentication**
   ```
   # Remove all 'md5' and 'password' lines from pg_hba.conf
   # Keep only 'gss' authentication
   ```

4. **Use Connection Pooling**
   - Implement connection pooling (pgBouncer, pgPool)
   - Reduce ticket validation overhead
   - Manage ticket renewal

5. **Monitor Authentication**
   ```sql
   -- Log all connections
   log_connections = on
   log_disconnections = on
   
   -- Audit authentication attempts
   SELECT datname, usename, application_name, client_addr
   FROM pg_stat_activity;
   ```

6. **Ticket Lifetime Management**
   - Set appropriate ticket lifetimes
   - Implement automatic ticket renewal
   - Handle ticket expiration gracefully

## Performance Considerations

### Connection Overhead

Kerberos adds minimal overhead:
- Initial ticket acquisition: ~50-100ms
- Subsequent connections: ~5-10ms (cached ticket)
- Use connection pooling for high-volume applications

### Benchmarking

```bash
# Test connection time
time psql -h postgres.example.com -U dbuser -d testdb -c "SELECT 1;"

# Compare with password auth
time PGPASSWORD=xxx psql -h postgres.example.com -U dbuser -d testdb -c "SELECT 1;"
```

## Real-World Applications

PostgreSQL with Kerberos is used for:

- **Enterprise Data Warehouses**: Centralized authentication for BI tools
- **Multi-Tenant Applications**: Secure tenant isolation
- **Compliance**: Audit trails and centralized access control
- **Cloud Databases**: Azure Database for PostgreSQL with Azure AD
- **Automated ETL**: Scripts accessing databases without embedded passwords
- **Microservices**: Service-to-service database authentication

## Advantages Over Password Authentication

| Feature | Kerberos | Password |
|---------|----------|----------|
| Credential Storage | None (uses tickets) | Must be stored/managed |
| Expiration | Automatic | Manual |
| Revocation | Immediate | Requires password change |
| Audit Trail | Complete | Limited |
| MFA Support | Yes (at kinit) | Depends on implementation |
| Network Security | Encrypted tickets | Password transmitted |

## Integration Examples

### With Connection Pooling (pgBouncer)

```ini
[databases]
testdb = host=postgres.example.com dbname=testdb

[pgbouncer]
auth_type = kerberos
auth_file = /etc/pgbouncer/userlist.txt
```

### With ORMs

**SQLAlchemy:**
```python
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql://dbuser@postgres.example.com/testdb",
    connect_args={"gssencmode": "prefer"}
)
```

**Django:**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'testdb',
        'USER': 'dbuser',
        'HOST': 'postgres.example.com',
        'OPTIONS': {
            'gssencmode': 'prefer',
        }
    }
}
```

## Next Steps

- Implement connection pooling with pgBouncer
- Set up PostgreSQL replication with Kerberos
- Integrate with application frameworks
- Configure automated ticket renewal
- Explore Azure Database for PostgreSQL with Azure AD

## Additional Resources

- [PostgreSQL GSSAPI Authentication](https://www.postgresql.org/docs/current/gssapi-auth.html)
- [psycopg2 Documentation](https://www.psycopg.org/docs/)
- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/auth-methods.html)
- [Kerberos and Databases - MIT](https://web.mit.edu/kerberos/krb5-latest/doc/)
