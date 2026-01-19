# Lab 04: Cross-Realm Trust

**Status:** ✅ Active  
**Difficulty:** Advanced  
**Prerequisites:** Understanding of Kerberos basics (Lab 01, Lab 02 recommended)  
**Duration:** 45-60 minutes

## Overview

Build a multi-realm Kerberos environment with bidirectional cross-realm trust relationships. This lab demonstrates how users from one realm can authenticate to services in another realm through trusted intermediaries.

## What You'll Learn

- Setting up multiple independent KDCs
- Configuring cross-realm trust principals (`krbtgt/REALM-B@REALM-A`)
- Understanding referral tickets
- Multi-realm authentication flows
- Trust path verification and ticket chains
- Cross-realm service access patterns
- Certificate authentication paths ([capaths])

## Architecture

```
┌────────────────────────┐                    ┌────────────────────────┐
│     REALM-A.LOCAL      │◄──── Trust ───────►│     REALM-B.LOCAL      │
│                        │                    │                        │
│  ┌──────────────────┐  │  krbtgt/B@A       │  ┌──────────────────┐  │
│  │  KDC-A           │  │  krbtgt/A@B       │  │  KDC-B           │  │
│  │  172.30.0.10     │  │                    │  │  172.30.0.20     │  │
│  └──────────────────┘  │                    │  └──────────────────┘  │
│                        │                    │                        │
│  Users:                │                    │  Users:                │
│  • alice               │                    │  • bob                 │
│                        │                    │                        │
│  ┌──────────────────┐  │                    │  ┌──────────────────┐  │
│  │  Service-A       │  │                    │  │  Service-B       │  │
│  │  (Port 8081)     │  │                    │  │  (Port 8082)     │  │
│  │  HTTP/svc-a      │  │                    │  │  HTTP/svc-b      │  │
│  └──────────────────┘  │                    │  └──────────────────┘  │
│                        │                    │                        │
│  ┌──────────────────┐  │                    │  ┌──────────────────┐  │
│  │  Client-A        │  │                    │  │  Client-B        │  │
│  │  172.30.0.30     │  │                    │  │  172.30.0.40     │  │
│  └──────────────────┘  │                    │  └──────────────────┘  │
└────────────────────────┘                    └────────────────────────┘
```

## Components

### Two Independent Realms

**REALM-A.LOCAL:**
- KDC: `kdc.realm-a.local` (172.30.0.10)
- Service: `service.realm-a.local` (172.30.0.15) - Port 8081
- Client: `client.realm-a.local` (172.30.0.30)
- User: `alice@REALM-A.LOCAL`

**REALM-B.LOCAL:**
- KDC: `kdc.realm-b.local` (172.30.0.20)
- Service: `service.realm-b.local` (172.30.0.25) - Port 8082
- Client: `client.realm-b.local` (172.30.0.40)
- User: `bob@REALM-B.LOCAL`

### Trust Principals

The trust is established through special cross-realm TGT principals:
- `krbtgt/REALM-B.LOCAL@REALM-A.LOCAL` - Allows REALM-A users to access REALM-B
- `krbtgt/REALM-A.LOCAL@REALM-B.LOCAL` - Allows REALM-B users to access REALM-A

## Quick Start

### 1. Setup

```bash
cd lab-04-cross-realm
./setup.sh
```

This automated script will:
- Create two independent KDCs
- Establish bidirectional trust relationship
- Create user principals (alice, bob)
- Create service principals with keytabs
- Deploy services in both realms
- Configure clients with proper krb5.conf

### 2. Test Cross-Realm Authentication

**Scenario 1: Alice (REALM-A) → Service-B (REALM-B)**

```bash
# Connect to REALM-A client
docker exec -it client-realm-a bash

# Authenticate as alice
kinit alice@REALM-A.LOCAL
# Password: alicepass123

# Access local service (same realm)
curl --negotiate -u : http://service.realm-a.local/secure/

# Access cross-realm service
curl --negotiate -u : http://service.realm-b.local/secure/

# Examine ticket chain
klist
# You should see:
# - krbtgt/REALM-A.LOCAL@REALM-A.LOCAL (TGT)
# - krbtgt/REALM-B.LOCAL@REALM-A.LOCAL (Referral)
# - HTTP/service.realm-b.local@REALM-B.LOCAL (Service)
```

**Scenario 2: Bob (REALM-B) → Service-A (REALM-A)**

```bash
# Connect to REALM-B client
docker exec -it client-realm-b bash

# Authenticate as bob
kinit bob@REALM-B.LOCAL
# Password: bobpass123

# Access cross-realm service
curl --negotiate -u : http://service.realm-a.local/secure/

# Examine ticket chain
klist
```

### 3. Run Automated Tests

```bash
docker exec -it client-realm-a /test-scripts/test-cross-realm.sh
```

## Understanding Cross-Realm Authentication

### The Ticket Chain

When alice@REALM-A.LOCAL accesses HTTP/service.realm-b.local@REALM-B.LOCAL:

```
1. Initial State:
   alice has TGT: krbtgt/REALM-A.LOCAL@REALM-A.LOCAL

2. Request Service Ticket:
   alice → KDC-A: "I need HTTP/service.realm-b.local@REALM-B.LOCAL"

3. KDC-A Issues Referral:
   KDC-A → alice: "Here's a referral: krbtgt/REALM-B.LOCAL@REALM-A.LOCAL"
   (This ticket says "REALM-A trusts this user, REALM-B should too")

4. Contact Remote KDC:
   alice → KDC-B: [Presents referral ticket]
   alice → KDC-B: "I need HTTP/service.realm-b.local@REALM-B.LOCAL"

5. KDC-B Validates and Issues Service Ticket:
   KDC-B: Validates referral from REALM-A
   KDC-B → alice: "Here's your service ticket: HTTP/service.realm-b.local@REALM-B.LOCAL"

6. Access Service:
   alice → Service-B: [Presents service ticket]
   Service-B: Validates ticket with its keytab
   Service-B: Grants access
```

### Configuration Keys

**krb5.conf - [capaths] Section:**

```ini
[capaths]
    REALM-A.LOCAL = {
        REALM-B.LOCAL = .
    }
    REALM-B.LOCAL = {
        REALM-A.LOCAL = .
    }
```

The `.` indicates a direct trust path (no intermediaries needed).

## Testing Scenarios

### Test 1: Same-Realm Access (Baseline)

```bash
# From client-a
kinit alice@REALM-A.LOCAL
curl --negotiate -u : http://service.realm-a.local/secure/
# Expected: 200 OK - Direct access, no referral needed
```

### Test 2: Cross-Realm Access

```bash
# alice → Service-B
curl --negotiate -u : http://service.realm-b.local/secure/
# Expected: 200 OK - Referral ticket acquired automatically

# Check ticket cache
klist
# Should show 3 tickets: TGT, referral, service ticket
```

### Test 3: Reverse Cross-Realm

```bash
# From client-b
kinit bob@REALM-B.LOCAL
curl --negotiate -u : http://service.realm-a.local/secure/
# Expected: 200 OK - Bidirectional trust works both ways
```

### Test 4: Ticket Chain Analysis

```bash
# Enable Kerberos tracing
export KRB5_TRACE=/dev/stdout

# Get ticket and observe the flow
kinit alice@REALM-A.LOCAL

# Access cross-realm service with full trace
curl --negotiate -u : http://service.realm-b.local/secure/

# You'll see detailed ticket acquisition process
```

### Test 5: Web Browser Access

```bash
# Access services through browser
# Service-A: http://localhost:8081
# Service-B: http://localhost:8082

# Note: Browser must be configured for SPNEGO
# (This works from the client containers with curl)
```

## Key Configuration Files

### Trust Principal Creation

On KDC-A:
```bash
kadmin.local -q "addprinc -pw TrustSecret123 krbtgt/REALM-B.LOCAL@REALM-A.LOCAL"
```

On KDC-B:
```bash
kadmin.local -q "addprinc -pw TrustSecret123 krbtgt/REALM-A.LOCAL@REALM-B.LOCAL"
```

⚠️ **Critical:** Both principals must use the **same password** for the trust to work.

### krb5.conf Configuration

Each client must know about both realms:

```ini
[realms]
    REALM-A.LOCAL = {
        kdc = kdc.realm-a.local
        admin_server = kdc.realm-a.local
    }
    REALM-B.LOCAL = {
        kdc = kdc.realm-b.local
        admin_server = kdc.realm-b.local
    }
```

## Troubleshooting

### Cross-Realm Authentication Fails

**Check trust principals exist:**
```bash
docker exec kdc-realm-a kadmin.local -q "listprincs" | grep krbtgt
docker exec kdc-realm-b kadmin.local -q "listprincs" | grep krbtgt
```

**Verify trust passwords match:**
```bash
# Both should have same kvno and enctypes
docker exec kdc-realm-a kadmin.local -q "getprinc krbtgt/REALM-B.LOCAL@REALM-A.LOCAL"
docker exec kdc-realm-b kadmin.local -q "getprinc krbtgt/REALM-A.LOCAL@REALM-B.LOCAL"
```

### Referral Ticket Not Acquired

**Check [capaths] configuration:**
```bash
docker exec client-realm-a cat /etc/krb5.conf | grep -A 10 capaths
```

**Verify KDC connectivity:**
```bash
docker exec client-realm-a ping -c 2 kdc.realm-b.local
```

**Test referral manually:**
```bash
kvno krbtgt/REALM-B.LOCAL@REALM-A.LOCAL
# Should succeed if trust is configured correctly
```

### Service Access Denied

**Check service principal exists:**
```bash
docker exec kdc-realm-b kadmin.local -q "listprincs" | grep HTTP/service.realm-b.local
```

**Verify keytab on service:**
```bash
docker exec service-realm-b klist -k /etc/keytabs/http.keytab
```

**Check Apache logs:**
```bash
docker exec service-realm-b cat /var/log/apache2/error.log
```

## Advanced Concepts

### Multi-Hop Trust

While this lab uses direct trust (indicated by `.` in capaths), real-world scenarios might involve multiple hops:

```ini
[capaths]
    REALM-A = {
        REALM-C = REALM-B
    }
```

This means to get from REALM-A to REALM-C, go through REALM-B.

### Hierarchical Realms

Organizations often structure realms hierarchically:

```
CORP.EXAMPLE.COM
├── US.CORP.EXAMPLE.COM
└── EU.CORP.EXAMPLE.COM
```

Child realms automatically trust parent realms.

### Trust Transitivity

If A trusts B, and B trusts C, does A trust C? **No, not automatically.**

Trust relationships must be explicitly configured unless using hierarchical realms.

## Security Considerations

1. **Trust Password Protection:** The shared secret for cross-realm principals must be strong and protected
2. **Selective Trust:** Only establish trust with realms you fully control or trust
3. **Audit Cross-Realm Access:** Monitor referral ticket usage
4. **Ticket Lifetime:** Cross-realm tickets often have shorter lifetimes
5. **Encryption Types:** Ensure compatible enctypes between realms

## Key Files

- [docker-compose.yml](docker-compose.yml) - Multi-realm container orchestration
- [Dockerfile.kdc](Dockerfile.kdc) - KDC container image
- [Dockerfile.service](Dockerfile.service) - Service container image
- [scripts/kdc-init.sh](scripts/kdc-init.sh) - KDC initialization with trust setup
- [config-a/krb5.conf](config-a/krb5.conf) - REALM-A client configuration
- [config-b/krb5.conf](config-b/krb5.conf) - REALM-B client configuration
- [setup.sh](setup.sh) - Automated setup script
- [test-scripts/test-cross-realm.sh](test-scripts/test-cross-realm.sh) - Comprehensive tests
- [.env.example](.env.example) - Configuration template

## Environment Variables

Copy `.env.example` to `.env`:

```bash
# Realm A
REALM_A=REALM-A.LOCAL
KDC_PASSWORD_A=PasswordA123
USER_PASSWORD_A=alicepass123
SERVICE_A_PORT=8081

# Realm B
REALM_B=REALM-B.LOCAL
KDC_PASSWORD_B=PasswordB123
USER_PASSWORD_B=bobpass123
SERVICE_B_PORT=8082

# Cross-Realm Trust
TRUST_PASSWORD=TrustSecret123  # Must be the same for both trust principals
```

## Cleanup

```bash
./cleanup.sh

# Or manually
docker-compose down -v
rm -rf keytabs
```

## Real-World Use Cases

Cross-realm trust is used for:

- **Corporate Mergers:** Integrate authentication between merged companies
- **Partner Access:** Allow partner employees to access shared services
- **Multi-Cloud:** Federate identity across cloud providers
- **Geographic Distribution:** Regional KDCs with central trust
- **Organizational Boundaries:** Department-specific realms with controlled sharing

## Lab Independence

This lab is **completely self-contained** with its own:
- Two independent KDCs
- Separate network (172.30.0.0/24)
- Dedicated services and clients
- No dependencies on other labs

## Next Steps

- **Lab 05:** Database authentication with Kerberos
- Explore three-realm trust relationships
- Implement hierarchical realm structures
- Set up constrained delegation across realms

## Additional Resources

- [MIT Kerberos Documentation - Cross-realm Authentication](https://web.mit.edu/kerberos/krb5-latest/doc/admin/realm_config.html#cross-realm-authentication)
- [RFC 4120 - Section 1.2: Cross-Realm Operation](https://tools.ietf.org/html/rfc4120#section-1.2)
- [Kerberos: The Definitive Guide - Chapter 8](http://shop.oreilly.com/product/9780596004033.do)
