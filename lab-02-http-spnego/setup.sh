#!/bin/bash
set -e

echo "========================================="
echo "Lab 02: HTTP SPNEGO Authentication Setup"
echo "========================================="
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

echo "Starting containers..."
docker-compose up -d

echo ""
echo "Waiting for KDC to be ready..."
sleep 10

echo ""
echo "Creating service principal and keytab for web server..."
docker exec kerberos-kdc-lab02 kadmin.local -q "addprinc -randkey HTTP/web.example.com@${REALM}"
docker exec kerberos-kdc-lab02 kadmin.local -q "ktadd -k /var/kerberos-data/http.keytab HTTP/web.example.com@${REALM}"

echo ""
echo "Copying keytab to web server..."
docker cp kerberos-kdc-lab02:/var/kerberos-data/http.keytab ./keytabs/http.keytab

echo ""
echo "Setting keytab permissions on web server..."
docker exec kerberos-web chown www-data:www-data /etc/keytabs/http.keytab
docker exec kerberos-web chmod 400 /etc/keytabs/http.keytab

echo ""
echo "Restarting web server to apply changes..."
docker restart kerberos-web

echo ""
echo "Creating test user principal..."
docker exec kerberos-kdc-lab02 kadmin.local -q "addprinc -pw ${USER_PASSWORD} ${USER_PRINCIPAL}"

echo ""
echo "Setting up Kerberos on client..."
docker exec kerberos-client-lab02 bash -c "
    apt-get update -qq && apt-get install -y krb5-user curl vim -qq > /dev/null
    cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${REALM} = {
        kdc = kdc.example.com
        admin_server = kdc.example.com
    }

[domain_realm]
    .example.com = ${REALM}
    example.com = ${REALM}
EOF
"

echo ""
echo "========================================="
echo "✓ Lab 02 Setup Complete!"
echo "========================================="
echo ""
echo "📝 Quick Start:"
echo ""
echo "1. Access the public page:"
echo "   http://localhost:${WEB_PORT}"
echo ""
echo "2. Test authentication from client:"
echo "   docker exec -it kerberos-client-lab02 bash"
echo "   kinit ${USER_PRINCIPAL}  # Password: ${USER_PASSWORD}"
echo "   curl --negotiate -u : http://web.example.com/secure/"
echo ""
echo "3. View your tickets:"
echo "   klist"
echo ""
echo "4. Test admin access (should succeed):"
echo "   curl --negotiate -u : http://web.example.com/admin/"
echo ""
echo "📚 For more details, see README.md"
echo ""
