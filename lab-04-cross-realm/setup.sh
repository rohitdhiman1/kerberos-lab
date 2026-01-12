#!/bin/bash
set -e

echo "============================================="
echo "Lab 04: Cross-Realm Trust Setup"
echo "============================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
    echo ""
fi

# Source environment variables
source .env

# Create keytabs directory
mkdir -p keytabs

echo "Starting containers..."
docker-compose up -d

echo ""
echo "Waiting for KDCs to be ready..."
sleep 15

echo ""
echo "============================================="
echo "Setting up REALM-A.LOCAL"
echo "============================================="

# Create user in Realm A
echo "Creating user alice@${REALM_A}..."
docker exec kdc-realm-a kadmin.local -q "addprinc -pw ${USER_PASSWORD_A} alice@${REALM_A}"

# Create service principal for Service A
echo "Creating service principal for Service-A..."
docker exec kdc-realm-a kadmin.local -q "addprinc -randkey HTTP/service.realm-a.local@${REALM_A}"
docker exec kdc-realm-a kadmin.local -q "ktadd -k /var/kerberos-data/http-a.keytab HTTP/service.realm-a.local@${REALM_A}"

# Copy keytab to service
docker cp kdc-realm-a:/var/kerberos-data/http-a.keytab ./keytabs/http-a.keytab
docker cp ./keytabs/http-a.keytab service-realm-a:/etc/keytabs/http.keytab

# Set permissions
docker exec service-realm-a chown www-data:www-data /etc/keytabs/http.keytab
docker exec service-realm-a chmod 400 /etc/keytabs/http.keytab

echo ""
echo "============================================="
echo "Setting up REALM-B.LOCAL"
echo "============================================="

# Create user in Realm B
echo "Creating user bob@${REALM_B}..."
docker exec kdc-realm-b kadmin.local -q "addprinc -pw ${USER_PASSWORD_B} bob@${REALM_B}"

# Create service principal for Service B
echo "Creating service principal for Service-B..."
docker exec kdc-realm-b kadmin.local -q "addprinc -randkey HTTP/service.realm-b.local@${REALM_B}"
docker exec kdc-realm-b kadmin.local -q "ktadd -k /var/kerberos-data/http-b.keytab HTTP/service.realm-b.local@${REALM_B}"

# Copy keytab to service
docker cp kdc-realm-b:/var/kerberos-data/http-b.keytab ./keytabs/http-b.keytab
docker cp ./keytabs/http-b.keytab service-realm-b:/etc/keytabs/http.keytab

# Set permissions
docker exec service-realm-b chown www-data:www-data /etc/keytabs/http.keytab
docker exec service-realm-b chmod 400 /etc/keytabs/http.keytab

echo ""
echo "============================================="
echo "Establishing Cross-Realm Trust"
echo "============================================="

# Create cross-realm principals in Realm A
echo "Creating cross-realm principal in Realm A..."
docker exec kdc-realm-a kadmin.local -q "addprinc -pw ${TRUST_PASSWORD} krbtgt/${REALM_B}@${REALM_A}"

# Create cross-realm principals in Realm B
echo "Creating cross-realm principal in Realm B..."
docker exec kdc-realm-b kadmin.local -q "addprinc -pw ${TRUST_PASSWORD} krbtgt/${REALM_A}@${REALM_B}"

echo ""
echo "Verifying cross-realm principals..."
docker exec kdc-realm-a kadmin.local -q "listprincs" | grep krbtgt
docker exec kdc-realm-b kadmin.local -q "listprincs" | grep krbtgt

echo ""
echo "Restarting services to apply changes..."
docker restart service-realm-a service-realm-b

echo ""
echo "Setting up clients..."

# Setup client A
docker exec client-realm-a bash -c "
    apt-get update -qq && apt-get install -y krb5-user curl vim iputils-ping -qq > /dev/null
    echo 'Client A ready'
"

# Setup client B
docker exec client-realm-b bash -c "
    apt-get update -qq && apt-get install -y krb5-user curl vim iputils-ping -qq > /dev/null
    echo 'Client B ready'
"

echo ""
echo "============================================="
echo "✓ Lab 04 Setup Complete!"
echo "============================================="
echo ""
echo "🌐 Two independent realms with cross-realm trust established!"
echo ""
echo "📝 Quick Start - Test Cross-Realm Authentication:"
echo ""
echo "1. Test from REALM-A client (alice accessing Service-B):"
echo "   docker exec -it client-realm-a bash"
echo "   kinit alice@${REALM_A}  # Password: ${USER_PASSWORD_A}"
echo "   curl --negotiate -u : http://service.realm-b.local/secure/"
echo "   klist  # See referral and service tickets"
echo ""
echo "2. Test from REALM-B client (bob accessing Service-A):"
echo "   docker exec -it client-realm-b bash"
echo "   kinit bob@${REALM_B}  # Password: ${USER_PASSWORD_B}"
echo "   curl --negotiate -u : http://service.realm-a.local/secure/"
echo "   klist  # See referral and service tickets"
echo ""
echo "3. Access web interfaces:"
echo "   Service-A: http://localhost:${SERVICE_A_PORT}"
echo "   Service-B: http://localhost:${SERVICE_B_PORT}"
echo ""
echo "4. Run automated tests:"
echo "   docker exec -it client-realm-a /test-scripts/test-cross-realm.sh"
echo ""
echo "📚 For detailed information, see README.md"
echo ""
