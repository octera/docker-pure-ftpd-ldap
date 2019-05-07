#!/bin/bash

# build up flags passed to this file on run + env flag for additional flags
# e.g. -e "ADDED_FLAGS=--tls=2"
PURE_FTPD_FLAGS=" $@ $ADDED_FLAGS "

# start rsyslog
if [[ "$PURE_FTPD_FLAGS" == *" -d "* ]] || [[ "$PURE_FTPD_FLAGS" == *"--verboselog"* ]]
then
    echo "Log enabled, see /var/log/messages"
    rsyslogd
fi

# detect if secret folder with cert is mounted, if yes generate PEM
if [ -e /secret/tls.key ] && [ -e /secret/tls.crt ]
then
    echo "Creating PEM file from key and crt"
    cat /secret/tls.crt /secret/tls.key > /etc/ssl/private/pure-ftpd.pem
fi

# detect if using TLS (from volumed in file) but no flag set, set one
if [ -e /etc/ssl/private/pure-ftpd.pem ] && [[ "$PURE_FTPD_FLAGS" != *"--tls"* ]]
then
    echo "TLS Enabled"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS --tls=1 "
fi

if [ ! -e /ldap/ldap.conf ]
then
	cp /ldap.conf /ldap/ldap.conf
fi

# If TLS flag is set and no certificate exists, generate it
if [ ! -e /etc/ssl/private/pure-ftpd.pem ] && [[ "$PURE_FTPD_FLAGS" == *"--tls"* ]] && [ ! -z "$TLS_CN" ] && [ ! -z "$TLS_ORG" ] && [ ! -z "$TLS_C" ]
then
    echo "Generating self-signed certificate"
    mkdir -p /etc/ssl/private
    if [[ "$TLS_USE_DSAPRAM" == "true" ]]; then
        openssl dhparam -dsaparam -out /etc/ssl/private/pure-ftpd-dhparams.pem 2048
    else
        openssl dhparam -out /etc/ssl/private/pure-ftpd-dhparams.pem 2048
    fi
    openssl req -subj "/CN=${TLS_CN}/O=${TLS_ORG}/C=${TLS_C}" -days 1826 \
        -x509 -nodes -newkey rsa:2048 -sha256 -keyout \
        /etc/ssl/private/pure-ftpd.pem \
        -out /etc/ssl/private/pure-ftpd.pem
    chmod 600 /etc/ssl/private/*.pem
fi

# Set a default value to the env var FTP_PASSIVE_PORTS
if [ -z "$FTP_PASSIVE_PORTS" ]
then
    FTP_PASSIVE_PORTS=30000:30009
fi

# Set passive port range in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -p "* ]]
then
    echo "Setting default port range to: $FTP_PASSIVE_PORTS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -p $FTP_PASSIVE_PORTS"
fi

# Set a default value to the env var FTP_MAX_CLIENTS
if [ -z "$FTP_MAX_CLIENTS" ]
then
    FTP_MAX_CLIENTS=5
fi

# Set max clients in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -c "* ]]
then
    echo "Setting default max clients to: $FTP_MAX_CLIENTS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -c $FTP_MAX_CLIENTS"
fi

# Set a default value to the env var FTP_MAX_CONNECTIONS
if [ -z "$FTP_MAX_CONNECTIONS" ]
then
    FTP_MAX_CONNECTIONS=5
fi

# Set max connections per ip in pure-ftpd options if not already existent
if [[ $PURE_FTPD_FLAGS != *" -C "* ]]
then
    echo "Setting default max connections per ip to: $FTP_MAX_CONNECTIONS"
    PURE_FTPD_FLAGS="$PURE_FTPD_FLAGS -C $FTP_MAX_CONNECTIONS"
fi

# let users know what flags we've ended with (useful for debug)
echo "Starting Pure-FTPd:"
echo "  pure-ftpd $PURE_FTPD_FLAGS"

# start pureftpd with requested flags
exec /usr/sbin/pure-ftpd-ldap $PURE_FTPD_FLAGS
