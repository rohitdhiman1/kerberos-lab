# Lab 03: SSH with Kerberos GSSAPI

**Status:** ✅ Active  
**Difficulty:** Intermediate  
**Prerequisites:** Understanding of Kerberos basics (Lab 01 recommended)  
**Duration:** 30-45 minutes

## Overview

Learn how to set up passwordless SSH authentication using Kerberos tickets and GSSAPI (Generic Security Services Application Program Interface). This lab demonstrates how SSH can leverage Kerberos for transparent, secure authentication without requiring passwords or SSH keys.

## What You'll Learn

- Configuring OpenSSH server for GSSAPI authentication
- Creating and deploying host principals
- Enabling credential delegation (ticket forwarding)
- Understanding SSH GSSAPI flow
- Testing passwordless authentication
- Troubleshooting SSH/Kerberos integration

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│     KDC     │◄────────┤ SSH Server  │◄────────┤   Client    │
│             │ Validates│             │   SSH   │             │
│ kdc.example │  Tickets│ssh.example  │  GSSAPI │client.ex... │
│    .com     │         │    .com     │   Auth  │    .com     │
└─────────────┘         └─────────────┘         └─────────────┘
      ▲                       │                       │
      │                       │                       │
      └───────────────────────┴───────────────────────┘
           Service Ticket: host/ssh.example.com
```

## Components

- **KDC Container**: Issues tickets for users and hosts
- **SSH Server**: OpenSSH configured with GSSAPI authentication
- **Client Container**: Pre-configured SSH client with Kerberos
- **Host Principal**: `host/ssh.example.com@EXAMPLE.COM`

## Quick Start

### 1. Setup

```bash
# Run the automated setup script
./setup.sh
```

This script will:
- Start all containers
- Create the host principal for SSH server
- Generate and deploy the host keytab
- Configure SSH server for GSSAPI
- Create a test user principal
- Set up the client environment

### 2. Test Passwordless SSH

```bash
# Enter the client container
docker exec -it ssh-client bash

# Obtain a Kerberos ticket
kinit testuser@EXAMPLE.COM
# Password: userpass123

# Verify your ticket
klist

# SSH to server - NO PASSWORD NEEDED!
ssh testuser@ssh.example.com

# You should be logged in without any password prompt
hostname  # Should show: ssh.example.com
whoami    # Should show: testuser

# Check if credentials were forwarded
klist

# Exit the SSH session
exit
```

### 3. Test from Your Local Machine

If you have Kerberos configured locally:

```bash
# SSH through the exposed port
ssh -p 2222 testuser@localhost
```

## Understanding SSH GSSAPI Authentication

### Authentication Flow

1. **Client has TGT** → User obtains initial ticket with `kinit`
2. **SSH connection initiated** → Client connects to SSH server
3. **GSSAPI negotiation** → Client and server agree to use GSSAPI
4. **Service ticket request** → Client requests `host/ssh.example.com` ticket from KDC
5. **Ticket presentation** → Client presents service ticket to SSH server
6. **Server validation** → SSH server validates ticket using its keytab
7. **Access granted** → User logged in without password

### Host Principal

SSH servers use a special principal format:
```
host/<hostname>@<REALM>
```

For this lab: `host/ssh.example.com@EXAMPLE.COM`

The server's keytab (stored at `/etc/krb5.keytab`) contains the keys needed to decrypt and validate Kerberos tickets.

## Configuration Details

### SSH Server Configuration (sshd_config)

Key settings for GSSAPI:

```ssh
# Enable GSSAPI authentication
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes

# Enable credential delegation (ticket forwarding)
GSSAPIKeyExchange yes
GSSAPIStoreCredentialsOnRekey yes
```

### SSH Client Configuration (ssh_config)

```ssh
Host *
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes
    GSSAPIKeyExchange yes
    PreferredAuthentications gssapi-with-mic,gssapi-keyex,publickey,password
```

## Testing Scenarios

### Test 1: Basic Authentication

```bash
# Get ticket
kinit testuser@EXAMPLE.COM

# Connect via SSH (no password!)
ssh testuser@ssh.example.com
```

### Test 2: Credential Delegation (Forwarding)

```bash
# Connect with credential forwarding
ssh -o GSSAPIDelegateCredentials=yes testuser@ssh.example.com

# On the remote host, check tickets
klist
# You should see your forwarded TGT!
```

This allows you to:
- Access other Kerberos-protected services from the SSH session
- SSH to another host without re-authenticating
- Use Kerberos-protected resources

### Test 3: Without Valid Ticket

```bash
# Destroy your ticket
kdestroy

# Try to connect with GSSAPI only
ssh -o PreferredAuthentications=gssapi-with-mic \
    -o PasswordAuthentication=no \
    testuser@ssh.example.com

# Should fail - no valid ticket
```

### Test 4: Remote Command Execution

```bash
# Execute command without interactive shell
ssh testuser@ssh.example.com "hostname && date && klist"

# The command runs on the remote host with your Kerberos context
```

### Test 5: Verify Service Ticket

```bash
# After SSH connection, check your ticket cache
klist

# You should see:
# krbtgt/EXAMPLE.COM@EXAMPLE.COM  (TGT)
# host/ssh.example.com@EXAMPLE.COM  (Service ticket)
```

## Automated Testing

Run the comprehensive test suite:

```bash
docker exec -it ssh-client /test-scripts/test-ssh.sh
```

Tests include:
- ✓ SSH server connectivity
- ✓ Kerberos ticket acquisition
- ✓ GSSAPI authentication
- ✓ Host service ticket validation
- ✓ Credential delegation/forwarding
- ✓ Access control without ticket
- ✓ Remote command execution
- ✓ Multiple concurrent sessions

## Advanced Features

### Credential Delegation

Credential delegation (forwarding) allows your Kerberos credentials to be forwarded to the remote host:

```bash
# Enable in command
ssh -K testuser@ssh.example.com  # -K enables delegation

# Or in ~/.ssh/config
Host ssh.example.com
    GSSAPIDelegateCredentials yes
```

**Use Cases:**
- Accessing other kerberized services from SSH session
- Chaining SSH connections
- Running scripts that need Kerberos authentication

**Security Warning:** Only delegate credentials to trusted hosts!

### Key Exchange with GSSAPI

Beyond authentication, GSSAPI can also be used for key exchange:

```
GSSAPIKeyExchange yes
```

This provides:
- Additional layer of protection
- Credential refresh during session
- Better integration with Kerberos infrastructure

## Troubleshooting

### SSH Connection Fails

```bash
# Check if you have a valid ticket
klist

# Verify ticket is not expired
# If expired, get new one
kinit testuser@EXAMPLE.COM

# Test connectivity
ping ssh.example.com
nc -zv ssh.example.com 22
```

### GSSAPI Authentication Not Working

```bash
# Enable verbose SSH output
ssh -vvv testuser@ssh.example.com

# Look for lines containing:
# - "GSSAPI"
# - "Kerberos"
# - "authentication"
```

### Service Ticket Not Obtained

```bash
# Check KDC logs
docker logs kerberos-kdc-lab03

# Verify host principal exists
docker exec kerberos-kdc-lab03 kadmin.local -q "listprincs" | grep host/

# Check server keytab
docker exec ssh-server klist -k /etc/krb5.keytab
```

### Server Configuration Issues

```bash
# Check SSH server logs
docker exec ssh-server cat /var/log/auth.log

# Verify GSSAPI is enabled
docker exec ssh-server grep -i gssapi /etc/ssh/sshd_config

# Test SSH config
docker exec ssh-server sshd -T | grep -i gssapi
```

### Credential Delegation Not Working

```bash
# Ensure ticket is forwardable
klist -f
# Should see 'F' flag

# Check SSH client config
ssh -G ssh.example.com | grep -i delegate

# Verify server allows forwarding
docker exec ssh-server grep -i gssapi /etc/ssh/sshd_config
```

## Key Files

- [docker-compose.yml](docker-compose.yml) - Container orchestration
- [Dockerfile.ssh](Dockerfile.ssh) - SSH server with Kerberos setup
- [krb5.conf](krb5.conf) - Kerberos client configuration
- [ssh-config/sshd_config](ssh-config/sshd_config) - SSH server GSSAPI configuration
- [ssh-config/ssh_config](ssh-config/ssh_config) - SSH client GSSAPI configuration
- [setup.sh](setup.sh) - Automated setup script
- [test-scripts/test-ssh.sh](test-scripts/test-ssh.sh) - Automated tests
- [.env.example](.env.example) - Configuration template

## Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
REALM=EXAMPLE.COM              # Kerberos realm
KDC_PASSWORD=Password123        # KDC admin password
SSH_PORT=2222                   # External SSH server port
USER_PRINCIPAL=testuser@EXAMPLE.COM
USER_PASSWORD=userpass123
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

1. **Host Keytab Protection**
   ```bash
   chown root:root /etc/krb5.keytab
   chmod 600 /etc/krb5.keytab
   ```

2. **Restrict Credential Delegation**
   - Only enable for trusted hosts
   - Use `GSSAPIStrictAcceptorCheck yes`

3. **Disable Password Fallback**
   ```ssh
   PasswordAuthentication no
   ChallengeResponseAuthentication no
   ```

4. **Limit GSSAPI Methods**
   ```ssh
   GSSAPIAuthentication yes
   GSSAPIKeyExchange no  # If not needed
   ```

5. **Monitor Access**
   - Log all authentication attempts
   - Alert on failed GSSAPI authentications
   - Track credential delegation usage

## Real-World Applications

SSH with Kerberos is used for:

- **Enterprise SSH Access**: Single sign-on for server management
- **Automated Scripts**: No need to manage SSH keys or passwords
- **Jump Hosts**: Credential delegation through bastion hosts
- **Cluster Management**: Access to thousands of nodes with one ticket
- **Compliance**: Centralized authentication audit trails

## Advantages Over SSH Keys

| Feature | Kerberos GSSAPI | SSH Keys |
|---------|-----------------|----------|
| Credential Management | Centralized | Distributed |
| Expiration | Automatic (ticket lifetime) | Manual |
| Revocation | Immediate | Requires key removal |
| Audit Trail | Complete | Limited |
| Password-free | ✓ | ✓ |
| Two-Factor Support | ✓ (at kinit) | Limited |

## Next Steps

- **Lab 04**: Cross-realm trust for multi-domain SSH access
- **Lab 05**: Database authentication with Kerberos
- Implement SSH certificate authorities
- Set up Ansible with Kerberos authentication
- Configure SSH bastion/jump hosts with delegation

## Additional Resources

- [OpenSSH GSSAPI Documentation](https://www.openssh.com/)
- [RFC 4462 - GSS-API Authentication and Key Exchange for SSH](https://tools.ietf.org/html/rfc4462)
- [Red Hat - Configuring SSH with Kerberos](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/configuring-ssh-to-use-kerberos-authentication_configuring-and-managing-idm)
