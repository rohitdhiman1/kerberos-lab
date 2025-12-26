# Lab 02: HTTP with SPNEGO Authentication

**Status:** ✅ Active  
**Difficulty:** Intermediate  
**Prerequisites:** Understanding of Kerberos basics (Lab 01 recommended)  
**Duration:** 30-45 minutes

## Overview

Learn how to implement Single Sign-On (SSO) for web applications using Kerberos SPNEGO (Simple and Protected GSSAPI Negotiation Mechanism) authentication. This lab demonstrates how HTTP services can authenticate users transparently using Kerberos tickets.

## What You'll Learn

- Creating service principals for HTTP services
- Generating and managing service keytabs
- Configuring Apache with `mod_auth_gssapi`
- Implementing different authorization policies
- Testing SPNEGO authentication with curl
- Understanding the SPNEGO negotiation flow

## Architecture

This lab creates three containers:

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│     KDC     │◄────────┤ Web Server  │◄────────┤   Client    │
│             │ Validates│  (Apache)   │  HTTP   │             │
│ kdc.example │  Tickets│web.example  │  SPNEGO │client.ex... │
│    .com     │         │    .com     │  Auth   │    .com     │
└─────────────┘         └─────────────┘         └─────────────┘
```

## Components

- **KDC Container**: Issues tickets for users and services
- **Apache Web Server**: Protected by Kerberos SPNEGO authentication
- **Client Container**: Pre-configured to test authentication
- **Service Principal**: `HTTP/web.example.com@EXAMPLE.COM`

## Quick Start

### 1. Setup

```bash
# Run the automated setup script
./setup.sh
```

This script will:
- Create the environment configuration
- Start all containers
- Create the HTTP service principal
- Generate and deploy the service keytab
- Create a test user principal

### 2. Access the Web Interface

Open your browser and navigate to:
```
http://localhost:8080
```

You'll see:
- **Public page** (/) - No authentication required
- **Secure area** (/secure) - Any valid Kerberos principal
- **Admin area** (/admin) - Only `testuser@EXAMPLE.COM`

### 3. Test Authentication from Client

```bash
# Enter the client container
docker exec -it kerberos-client-lab02 bash

# Obtain a Kerberos ticket
kinit testuser@EXAMPLE.COM
# Password: userpass123

# Test access to public page
curl http://web.example.com/

# Test access to secure page with SPNEGO
curl --negotiate -u : http://web.example.com/secure/

# Test admin access
curl --negotiate -u : http://web.example.com/admin/

# View your tickets
klist

# Exit the container
exit
```

## Understanding the Configuration

### Apache GSSAPI Configuration

The authentication is configured in [apache-config/auth.conf](apache-config/auth.conf):

```apache
<Location "/secure">
    AuthType GSSAPI
    AuthName "Kerberos Login"
    GssapiCredStore keytab:/etc/keytabs/http.keytab
    GssapiLocalName on
    Require valid-user
</Location>
```

**Key directives:**
- `AuthType GSSAPI` - Use Kerberos authentication
- `GssapiCredStore` - Path to service keytab
- `GssapiLocalName on` - Strip realm from username
- `Require valid-user` - Any authenticated user

### Service Principal

The HTTP service uses the principal:
```
HTTP/web.example.com@EXAMPLE.COM
```

**Format:** `HTTP/<hostname>@<REALM>`

The service's keytab file contains the keys needed to decrypt and validate Kerberos tickets.

## Testing Scenarios

### Test 1: Public Access
```bash
# Should return 200 OK without authentication
curl -v http://web.example.com/
```

### Test 2: Protected Resource Without Ticket
```bash
# Should return 401 Unauthorized
curl -v http://web.example.com/secure/
```

### Test 3: Protected Resource With Ticket
```bash
# Get ticket first
echo "userpass123" | kinit testuser@EXAMPLE.COM

# Should return 200 OK
curl --negotiate -u : http://web.example.com/secure/

# Verify service ticket was obtained
klist
# You should see: HTTP/web.example.com@EXAMPLE.COM
```

### Test 4: Specific Principal Authorization
```bash
# testuser should succeed
curl --negotiate -u : http://web.example.com/admin/

# Create another user and test (should fail)
docker exec kerberos-kdc-lab02 kadmin.local -q "addprinc -pw pass123 otheruser"
kdestroy
echo "pass123" | kinit otheruser@EXAMPLE.COM
curl --negotiate -u : http://web.example.com/admin/
# Should return 403 Forbidden
```

## Automated Testing

Run the comprehensive test suite:

```bash
docker exec -it kerberos-client-lab02 /test-scripts/test-auth.sh
```

This tests:
- ✓ Public page access without authentication
- ✓ Protected page requires authentication
- ✓ Ticket acquisition
- ✓ SPNEGO authentication with valid ticket
- ✓ Principal-based authorization
- ✓ Service ticket acquisition
- ✓ Access denial after ticket destruction

## How SPNEGO Works

1. **Client requests protected resource** → Server responds with `401` and `WWW-Authenticate: Negotiate`
2. **Client obtains service ticket** → From KDC using user's TGT
3. **Client sends ticket** → In `Authorization: Negotiate <token>` header
4. **Server validates ticket** → Using its keytab
5. **Server grants access** → Returns `200 OK` with content

## Troubleshooting

### Authentication Fails (401)

```bash
# Check if you have a valid ticket
klist

# Verify ticket is not expired
# If expired, get a new one
kinit testuser@EXAMPLE.COM

# Check DNS resolution
docker exec kerberos-client-lab02 ping -c 2 web.example.com
```

### Service Ticket Not Obtained

```bash
# Check KDC logs
docker logs kerberos-kdc-lab02

# Verify service principal exists
docker exec kerberos-kdc-lab02 kadmin.local -q "listprincs"

# Check keytab is readable
docker exec kerberos-web ls -l /etc/keytabs/http.keytab
```

### Apache Errors

```bash
# Check Apache error logs
docker exec kerberos-web cat /var/log/apache2/error.log

# Verify mod_auth_gssapi is loaded
docker exec kerberos-web apache2ctl -M | grep gssapi

# Restart Apache
docker restart kerberos-web
```

## Key Files

- [docker-compose.yml](docker-compose.yml) - Container orchestration
- [Dockerfile](Dockerfile) - Apache with Kerberos setup
- [krb5.conf](krb5.conf) - Kerberos client configuration
- [apache-config/auth.conf](apache-config/auth.conf) - GSSAPI authentication rules
- [setup.sh](setup.sh) - Automated setup script
- [test-scripts/test-auth.sh](test-scripts/test-auth.sh) - Automated tests
- [.env.example](.env.example) - Configuration template

## Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
REALM=EXAMPLE.COM          # Kerberos realm
KDC_PASSWORD=Password123    # KDC admin password
WEB_PORT=8080              # External web server port
USER_PRINCIPAL=testuser@EXAMPLE.COM
USER_PASSWORD=userpass123
```

## Cleanup

```bash
# Stop and remove all containers and volumes
./cleanup.sh

# Or manually
docker-compose down -v
rm -f keytabs/http.keytab
```

## Real-World Applications

This pattern is used in enterprise environments for:

- **Intranet portals** - Automatic login for corporate users
- **Internal APIs** - Service-to-service authentication
- **Admin interfaces** - Secure access without password prompts
- **Cloud applications** - Azure AD + Kerberos federation

## Next Steps

- **Lab 03**: SSH with Kerberos GSSAPI authentication
- **Lab 04**: Cross-realm trust configurations
- **Lab 05**: Database authentication with Kerberos

## Additional Resources

- [RFC 4559 - SPNEGO-based Kerberos and NTLM HTTP Authentication](https://tools.ietf.org/html/rfc4559)
- [mod_auth_gssapi Documentation](https://github.com/gssapi/mod_auth_gssapi)
- [Apache HTTP Server Documentation](https://httpd.apache.org/docs/)
