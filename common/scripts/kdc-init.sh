#!/bin/bash
set -e

# --- 1. Populate Config Files from Templates ---
echo "Populating Kerberos configuration files from templates..."
envsubst < /etc/krb5.conf.template > /etc/krb5.conf
envsubst < /etc/krb5kdc/kdc.conf.template > /etc/krb5kdc/kdc.conf

# Create the admin ACL file - grants full access to the admin principal
echo "*/admin@${KRB_REALM} *" > /etc/krb5kdc/kadm5.acl

# --- 2. Initialize KDC Database (One-time setup) ---
KRB_DB_DIR="/var/lib/krb5kdc"
if [ ! -f "${KRB_DB_DIR}/principal" ]; then
    echo "Kerberos database not found. Initializing new realm: ${KRB_REALM}..."
    
    # Create the KDC database and stash file with the master password
    echo "Creating KDC database. Master password: ${KRB_MASTER_PASSWORD}"
    kdb5_util create -s -r ${KRB_REALM} -P "${KRB_MASTER_PASSWORD}"

    # Start kadmin.local to create the admin principal
    echo "Creating admin principal: ${KRB_ADMIN_PRINCIPAL}@${KRB_REALM}..."
    /usr/sbin/kadmin.local -q "addprinc -pw ${KRB_ADMIN_PASSWORD} ${KRB_ADMIN_PRINCIPAL}"
    
    # Create a keytab for the KDC admin server (kadmind)
    echo "Creating keytab for kadmind service..."
    /usr/sbin/kadmin.local -q "ktadd -k /etc/krb5kdc/kadm5.keytab kadmin/admin"

    echo "KDC Initialization Complete."
else
    echo "Kerberos database already exists. Skipping initialization."
fi

# --- 3. Start KDC and Admin Server ---
echo "Starting krb5kdc and kadmind services..."
/usr/sbin/krb5kdc
/usr/sbin/kadmind

# Keep the container running
tail -f /var/log/krb5kdc.log