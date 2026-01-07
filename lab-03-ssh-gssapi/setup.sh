#!/bin/bash
set -e

echo "========================================="
echo "Lab 03: SSH with Kerberos GSSAPI Setup"
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

# Create keytabs directory
mkdir -p keytabs

echo "Starting containers..."
docker-compose up -d

echo ""
echo "Waiting for KDC to be ready..."
sleep 10

echo ""
echo "Creating host principal for SSH server..."
docker exec kerberos-kdc-lab03 kadmin.local -q "addprinc -randkey host/ssh.example.com@${REALM}"
docker exec kerberos-kdc-lab03 kadmin.local -q "ktadd -k /var/kerberos-data/ssh.keytab host/ssh.example.com@${REALM}"

echo ""
echo "Copying keytab to SSH server..."
docker cp kerberos-kdc-lab03:/var/kerberos-data/ssh.keytab ./keytabs/ssh.keytab
docker cp ./keytabs/ssh.keytab ssh-server:/etc/krb5.keytab

echo ""
echo "Setting keytab permissions on SSH server..."
docker exec ssh-server chown root:root /etc/krb5.keytab
docker exec ssh-server chmod 600 /etc/krb5.keytab

echo ""
echo "Applying SSH configuration..."
docker exec ssh-server bash -c "cp /etc/ssh/sshd_config.kerberos /etc/ssh/sshd_config"

echo ""
echo "Creating test user principal..."
docker exec kerberos-kdc-lab03 kadmin.local -q "addprinc -pw ${USER_PASSWORD} ${USER_PRINCIPAL}"

echo ""
echo "Restarting SSH server to apply changes..."
docker restart ssh-server
sleep 5

echo ""
echo "Setting up SSH client..."
docker exec ssh-client bash -c "
    apt-get update -qq && apt-get install -y openssh-client krb5-user vim iputils-ping -qq > /dev/null
    echo 'SSH client ready'
"

echo ""
echo "Verifying SSH server is running..."
docker exec ssh-client bash -c "nc -zv ssh.example.com 22" 2>&1 | grep -q "succeeded" && echo "✓ SSH server is accessible" || echo "⚠️  SSH server may not be ready"

echo ""
echo "========================================="
echo "✓ Lab 03 Setup Complete!"
echo "========================================="
echo ""
echo "📝 Quick Start:"
echo ""
echo "1. Connect to client container:"
echo "   docker exec -it ssh-client bash"
echo ""
echo "2. Obtain Kerberos ticket:"
echo "   kinit ${USER_PRINCIPAL}  # Password: ${USER_PASSWORD}"
echo ""
echo "3. Verify your ticket:"
echo "   klist"
echo ""
echo "4. SSH to server using GSSAPI (no password needed!):"
echo "   ssh testuser@ssh.example.com"
echo ""
echo "5. Check delegated credentials on remote host:"
echo "   klist  # Should show forwarded ticket"
echo ""
echo "6. From your local machine (requires Kerberos setup):"
echo "   ssh -p ${SSH_PORT} testuser@localhost"
echo ""
echo "7. Run automated tests:"
echo "   docker exec -it ssh-client /test-scripts/test-ssh.sh"
echo ""
echo "📚 For more details, see README.md"
echo ""
