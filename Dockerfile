FROM ubuntu:22.04

# Install Kerberos KDC, client tools, and utilities
RUN apt-get update \
    && apt-get install -y \
    krb5-kdc \
    krb5-admin-server \
    krb5-config \
    krb5-user \
    gettext-base \
    net-tools \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration templates and the initialization script
COPY config/krb5.conf.template /etc/krb5.conf.template
COPY config/kdc.conf.template /etc/krb5kdc/kdc.conf.template
COPY kdc-init.sh /usr/local/bin/kdc-init.sh

# Set the initialization script as the entrypoint
RUN chmod +x /usr/local/bin/kdc-init.sh

# Kerberos KDC: 88 (UDP/TCP), Admin Server: 749 (TCP), Password Server: 464 (UDP/TCP)
EXPOSE 88/tcp 88/udp 749/tcp 464/tcp 464/udp

# Set the entrypoint to run the initialization script
ENTRYPOINT ["/usr/local/bin/kdc-init.sh"]