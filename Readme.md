# Kerberos Learning Labs

A comprehensive, hands-on Kerberos learning environment using Docker. Each lab is self-contained and builds upon core Kerberos concepts.

## 🎯 Lab Structure

Each lab is independent and can be run separately. All labs share common configuration templates and scripts from the `common/` directory.

## 📚 Available Labs

### Lab 01: Basic KDC Setup ✅
**Status:** Complete  
**Path:** `lab-01-basic-kdc/`  
**Difficulty:** Beginner  

Learn the fundamentals of Kerberos by setting up a KDC and client:
- KDC initialization and database creation
- Principal management with kadmin
- Obtaining and using tickets (kinit, klist, kdestroy)
- Understanding realms and principals

**Quick Start:**
```bash
cd lab-01-basic-kdc
cp .env.example .env
# Edit .env with your preferences
docker-compose up --build -d
```

### Lab 02: HTTP with SPNEGO Authentication
**Status:** Planned  
**Path:** `lab-02-http-spnego/`  
**Difficulty:** Intermediate  

Implement web Single Sign-On:
- Apache/Nginx with mod_auth_gssapi
- Service principals and keytabs
- Browser-based SSO
- Troubleshooting authentication flows

### Lab 03: SSH with Kerberos GSSAPI
**Status:** Planned  
**Path:** `lab-03-ssh-gssapi/`  
**Difficulty:** Intermediate  

Passwordless SSH with Kerberos:
- SSH server with GSSAPI authentication
- Credential delegation
- Ticket forwarding
- Host principal management

### Lab 04: Cross-Realm Trust
**Status:** Planned  
**Path:** `lab-04-cross-realm/`  
**Difficulty:** Advanced  

Multiple realms with trust relationships:
- Setting up two independent KDCs
- Configuring cross-realm principals
- Trust relationships and path verification
- Multi-realm authentication flows

**Note:** This lab is completely self-contained with its own KDCs.

### Lab 05: Database Authentication
**Status:** Planned  
**Path:** `lab-05-database-auth/`  
**Difficulty:** Advanced  

Secure database access:
- PostgreSQL with Kerberos authentication
- Service principal configuration
- Client connection strings
- Keytab management for services

## 🗂️ Common Resources

The `common/` directory contains shared resources used across all labs:
- **config-templates/**: Kerberos configuration file templates
- **scripts/**: Reusable initialization and utility scripts

**Note:** You don't need to "run" the common folder - it's automatically referenced by each lab's Dockerfile.

## 🚀 Getting Started

1. **Prerequisites:**
   - Docker and Docker Compose installed
   - Basic understanding of authentication concepts

2. **Start with Lab 01:**
   ```bash
   cd lab-01-basic-kdc
   cat README.md  # Read the lab guide
   ```

3. **Complete labs in order** or jump to specific topics of interest

## 📖 Learning Path

**Beginner Track:**
1. Lab 01 → Lab 02 → Lab 03

**Advanced Track:**
1. Complete Beginner Track
2. Lab 04 → Lab 05

## 🛠️ Project Structure

```
kerberos-lab/
├── README.md                    # This file
├── common/                      # Shared resources (not runnable)
│   ├── config-templates/
│   └── scripts/
├── lab-01-basic-kdc/           # Each lab is self-contained
├── lab-02-http-spnego/
├── lab-03-ssh-gssapi/
├── lab-04-cross-realm/
└── lab-05-database-auth/
```

## 🤝 Contributing

Feel free to add new labs or improve existing ones!

## 📝 License

Educational use - learn and share freely.



