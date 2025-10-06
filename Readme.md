
# Kerberos Lab Execution and Testing Guide

This guide details the steps required to launch, verify, and interact with the Dockerized Kerberos KDC lab, assuming you have completed the setup of `Dockerfile`, `docker-compose.yml`, `kdc-init.sh`, and the secret `.env` file.

## Prerequisites

- Docker and Docker Compose installed.

---

## Step 1: Lab Execution (Build and Run)

This step initializes the entire Kerberos ecosystem. On the first run, the KDC database is created using the passwords defined in your local `.env` file.

### 1.1 Prepare Local Volumes

Before running Docker Compose, ensure the host directories defined in your `.env` file for persistent data storage exist.

```sh
# Create the necessary host directories for persistent data
mkdir -p volumes/kdc-db volumes/config volumes/keytabs
```

### 1.2 Build and Start the Services

The `--build` flag ensures your custom Dockerfile is processed, and the `-d` flag runs the containers in detached mode (background).

```sh
# Build the images and start the KDC and Client services
docker-compose up --build -d
```

### 1.3 Monitor Initialization (First Run)

The KDC container will run the `kdc-init.sh` script, which:

- Generates the final `krb5.conf` and `kdc.conf` using your `.env` variables.
- Creates the Kerberos database, stashing the master key.
- Adds the administration principal (`admin/admin`).

Check the logs for completion:

```sh
# Follow the KDC logs to confirm database creation and service start
docker logs kerberos-kdc -f
```

You should see confirmation that the realm was initialized and that `krb5kdc` and `kadmind` are running. Use `Ctrl+C` to exit the logs.

---

## Step 2: Lab Verification and Health Check

### 2.1 Check Service Status

Verify that both containers are running and that the KDC service is reported as healthy.

```sh
docker-compose ps
```

| Service          | State | Health   | Notes                                                        |
|------------------|-------|----------|--------------------------------------------------------------|
| kerberos-kdc     | Up    | healthy  | KDC is initialized and listening on ports 88 and 749         |
| kerberos-client  | Up    |          | This is your environment for testing                         |

### 2.2 Verify Generated Configuration

Confirm that the shared `krb5.conf` file was successfully generated and mounted on your host.

```sh
# View the final, populated krb5.conf file on your host machine
cat ./volumes/config/krb5.conf
```

The output should show your specific realm name (e.g., `DEV.LOCAL`) and hostname (e.g., `kdc.dev.local`) substituted for the template variables.

---

## Step 3: Interactive Testing (Kinit and Kadmin)

The client container is pre-configured to use the KDC via the shared `krb5.conf` file.

### 3.1 Enter the Client Container

```sh
docker exec -it kerberos-client bash
```

### 3.2 Obtain an Initial Ticket (TGT)

Use the admin principal created during initialization to get a Ticket-Granting Ticket (TGT).

```sh
# Replace KRB_ADMIN_PRINCIPAL with your actual value (e.g., admin/admin)
ADMIN_PRINCIPAL=$(grep KRB_ADMIN_PRINCIPAL /keytabs/dummy.env | cut -d'=' -f2) # Use environment variable if available
REALM=$(grep KRB_REALM /keytabs/dummy.env | cut -d'=' -f2) # Use environment variable if available

# If running directly, use the configured name:
kinit admin/admin
# Enter Password: (Use your KRB_ADMIN_PASSWORD from the .env file)
```

### 3.3 Verify the Ticket Cache

Confirm the TGT was successfully issued and stored in the credential cache.

```sh
klist
```

**Expected Output:** You should see a ticket for `krbtgt/DEV.LOCAL@DEV.LOCAL`.

### 3.4 Provision a Service Principal and Keytab

Use the `kadmin` utility (which authenticates using your TGT) to create a new service principal and export its key to a keytab file.

```sh
# Access kadmin remotely using your TGT
kadmin

# In the kadmin shell:
# 1. Add a service principal (e.g., for an HTTP service)
addprinc -randkey HTTP/web.dev.local

# 2. Export the key for this service principal to the mounted volume
ktadd -k /keytabs/web_service.keytab HTTP/web.dev.local

# 3. Exit kadmin
exit
```

### 3.5 Verify Keytab Contents (Host)

Exit the client container and check that the keytab file was created successfully on your host machine.

```sh
exit # Exit the client container
ktutil --keytab=volumes/keytabs/web_service.keytab list
```

**Expected Output:** The `ktutil` output should show keys (versions) for the `HTTP/web.dev.local` principal. This confirms that provisioning works and secrets (keytabs) are properly isolated to the host volume.

---

## Step 4: Cleanup

When you are done, stop and remove the containers.

### 4.1 Stop Services

```sh
docker-compose down
```

### 4.2 Optional: Remove Persistent Data

If you want to start a completely fresh KDC instance, you must remove the persistent volumes. 

> **WARNING:** This permanently deletes your Kerberos database and all generated keys/principals.

```sh
# WARNING: Deletes the Kerberos database, all principals, and keytabs
rm -rf volumes/kdc-db volumes/config volumes/keytabs
```
