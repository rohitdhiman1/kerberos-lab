# Common Resources for Kerberos Labs

This directory contains shared configuration templates and scripts used across all labs.

## Directory Structure

```
common/
├── config-templates/
│   ├── krb5.conf.template      # Client/server Kerberos config
│   └── kdc.conf.template       # KDC-specific configuration
└── scripts/
    └── kdc-init.sh             # KDC initialization script
```

## Usage

Each lab's Dockerfile references these files using relative paths:

```dockerfile
COPY ../common/config-templates/krb5.conf.template /etc/krb5.conf.template
COPY ../common/scripts/kdc-init.sh /usr/local/bin/kdc-init.sh
```

## Template Variables

Configuration templates use environment variables (substituted via `envsubst`):

- `KRB_REALM` - Kerberos realm name
- `KRB_KDC_HOSTNAME` - KDC server hostname
- `KRB_MASTER_PASSWORD` - KDC database master key
- `KRB_ADMIN_PRINCIPAL` - Admin principal name
- `KRB_ADMIN_PASSWORD` - Admin principal password

## Note

You don't need to run anything in this directory directly. Labs automatically reference these files during their build process.
