#!/bin/bash
set -e

echo "==========================================="
echo "Initializing KDC for realm: ${REALM}"
echo "==========================================="

# Create KDC configuration
cat > /etc/krb5kdc/kdc.conf << EOF
[kdcdefaults]
    kdc_ports = 88
    kdc_tcp_ports = 88

[realms]
    ${REALM} = {
        kadmind_port = 749
        max_life = 12h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = aes256-cts
        supported_enctypes = aes256-cts:normal aes128-cts:normal
        default_principal_flags = +preauth
    }
EOF

# Create Kerberos client configuration
cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
    ${REALM} = {
        kdc = $(hostname -f)
        admin_server = $(hostname -f)
    }
    ${PEER_REALM} = {
        kdc = ${PEER_KDC}
        admin_server = ${PEER_KDC}
    }

[domain_realm]
    .realm-a.local = REALM-A.LOCAL
    realm-a.local = REALM-A.LOCAL
    .realm-b.local = REALM-B.LOCAL
    realm-b.local = REALM-B.LOCAL

[capaths]
    ${REALM} = {
        ${PEER_REALM} = .
    }
    ${PEER_REALM} = {
        ${REALM} = .
    }
EOF

# Create KDC database
echo "Creating KDC database..."
kdb5_util create -s -r ${REALM} -P ${KDC_PASSWORD}

# Start KDC services
echo "Starting KDC services..."
krb5kdc
kadmind

echo "KDC for ${REALM} is running"

# Keep container running
tail -f /dev/null
