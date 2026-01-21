#!/bin/bash
set -e

echo "============================================="
echo "Lab 05: Database Authentication with Kerberos"
echo "============================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
    echo ""
    echo "⚠️  Please review and update .env file if needed"
    echo ""
fi

# Source environment variables
source .env

# Create keytabs directory
mkdir -p keytabs

echo "Starting containers..."
docker-compose up -d

echo ""
echo "Waiting for KDC to be ready..."
sleep 10

echo ""
echo "Creating PostgreSQL service principal..."
docker exec kerberos-kdc-lab05 kadmin.local -q "addprinc -randkey postgres/postgres.example.com@${REALM}"
docker exec kerberos-kdc-lab05 kadmin.local -q "ktadd -k /var/kerberos-data/postgres.keytab postgres/postgres.example.com@${REALM}"

echo ""
echo "Copying keytab to PostgreSQL server..."
docker cp kerberos-kdc-lab05:/var/kerberos-data/postgres.keytab ./keytabs/postgres.keytab
docker cp ./keytabs/postgres.keytab postgres-kerberos:/etc/keytabs/postgres.keytab

echo ""
echo "Setting keytab permissions..."
docker exec postgres-kerberos chown postgres:postgres /etc/keytabs/postgres.keytab
docker exec postgres-kerberos chmod 400 /etc/keytabs/postgres.keytab

echo ""
echo "Creating database user principal..."
docker exec kerberos-kdc-lab05 kadmin.local -q "addprinc -pw ${DB_PASSWORD} dbuser@${REALM}"

echo ""
echo "Configuring PostgreSQL for Kerberos..."
docker exec -u postgres postgres-kerberos bash -c "
    # Copy custom config
    cp /etc/postgresql/postgresql.conf /var/lib/postgresql/data/postgresql.conf
    cp /etc/postgresql/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf
"

echo ""
echo "Creating database user in PostgreSQL..."
docker exec postgres-kerberos psql -U postgres -c "CREATE ROLE dbuser WITH LOGIN;"
docker exec postgres-kerberos psql -U postgres -c "GRANT CONNECT ON DATABASE testdb TO dbuser;"
docker exec postgres-kerberos psql -U postgres -d testdb -c "GRANT USAGE ON SCHEMA demo TO dbuser;"
docker exec postgres-kerberos psql -U postgres -d testdb -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA demo TO dbuser;"
docker exec postgres-kerberos psql -U postgres -d testdb -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA demo TO dbuser;"

echo ""
echo "Restarting PostgreSQL to apply configuration..."
docker restart postgres-kerberos
sleep 10

echo ""
echo "Setting up database client..."
docker exec db-client bash -c "
    apt-get update -qq && apt-get install -y \
        postgresql-client \
        krb5-user \
        python3 \
        python3-pip \
        vim \
        iputils-ping \
        -qq > /dev/null
    
    pip3 install psycopg2-binary --quiet
    echo 'Database client ready'
"

echo ""
echo "Verifying PostgreSQL is ready..."
sleep 5
docker exec db-client bash -c "pg_isready -h postgres.example.com -p 5432" && echo "✓ PostgreSQL is ready" || echo "⚠️  PostgreSQL may not be ready"

echo ""
echo "============================================="
echo "✓ Lab 05 Setup Complete!"
echo "============================================="
echo ""
echo "📝 Quick Start:"
echo ""
echo "1. Connect to client container:"
echo "   docker exec -it db-client bash"
echo ""
echo "2. Obtain Kerberos ticket:"
echo "   kinit dbuser@${REALM}  # Password: ${DB_PASSWORD}"
echo ""
echo "3. Verify your ticket:"
echo "   klist"
echo ""
echo "4. Connect to PostgreSQL using Kerberos (no password!):"
echo "   psql -h postgres.example.com -U dbuser -d testdb"
echo ""
echo "5. Run sample queries:"
echo "   SELECT * FROM demo.employees;"
echo "   SELECT * FROM demo.departments;"
echo ""
echo "6. Test with Python:"
echo "   python3 /client-examples/connect.py"
echo ""
echo "7. Run automated tests:"
echo "   /test-scripts/test-db-auth.sh"
echo ""
echo "8. Connect from localhost (if you have psql and Kerberos):"
echo "   psql -h localhost -p ${POSTGRES_PORT} -U dbuser -d testdb"
echo ""
echo "📚 For more details, see README.md"
echo ""
