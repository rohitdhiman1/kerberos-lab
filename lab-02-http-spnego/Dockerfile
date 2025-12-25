FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Apache, Kerberos, and required modules
RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-auth-gssapi \
    krb5-user \
    krb5-config \
    curl \
    vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Enable required Apache modules
RUN a2enmod auth_gssapi \
    && a2enmod headers \
    && a2enmod rewrite

# Create directories for keytabs and configuration
RUN mkdir -p /etc/keytabs /var/www/html

# Copy Kerberos client configuration
COPY krb5.conf /etc/krb5.conf

# Enable custom auth configuration
RUN a2enconf auth

EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]
