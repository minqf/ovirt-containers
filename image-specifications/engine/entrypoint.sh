#!/bin/bash
set -e

cp -f answers.conf.in answers.conf
echo OVESETUP_DB/user=str:$POSTGRES_USER >> answers.conf
echo OVESETUP_DB/password=str:$POSTGRES_PASSWORD >> answers.conf
echo OVESETUP_DB/database=str:$POSTGRES_DB >> answers.conf
echo OVESETUP_DB/host=str:$POSTGRES_HOST >> answers.conf
echo OVESETUP_DB/port=str:$POSTGRES_PORT >> answers.conf
echo OVESETUP_ENGINE_CONFIG/fqdn=str:$OVIRT_FQDN >> answers.conf
echo OVESETUP_CONFIG/fqdn=str:$OVIRT_FQDN >> answers.conf
echo OVESETUP_CONFIG/adminPassword=str:$OVIRT_PASSWORD >> answers.conf
echo OVESETUP_PKI/organization=str:$OVIRT_PKI_ORGANIZATION >> answers.conf

# On the first run, copy pki template files into original
# template location because kubernetes mounts hide
# the original files in the image.
if [ ! -f /etc/pki/ovirt-engine/serial.txt ]; then
    cp -a /etc/pki/ovirt-engine.tmpl/* /etc/pki/ovirt-engine/
fi
chown ovirt:ovirt /etc/pki/ovirt-engine

# Wait for postgres
dockerize -wait tcp://${POSTGRES_HOST}:${POSTGRES_PORT} -timeout 1m

scl enable rh-postgresql95 -- engine-setup --config=answers.conf --offline

if [ -n "$SPICE_PROXY" ]; then
  engine-config -s SpiceProxyDefault=$SPICE_PROXY
fi

# SSO configuration
echo SSO_ALTERNATE_ENGINE_FQDNS="\"$SSO_ALTERNATE_ENGINE_FQDNS\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
echo ENGINE_SSO_SERVICE_SSL_VERIFY_HOST=false >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf

if [ -n "$ENGINE_SSO_AUTH_URL" ]; then
  echo ENGINE_SSO_INSTALLED_ON_ENGINE_HOST=false >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
  echo "ENGINE_SSO_AUTH_URL=\"$ENGINE_SSO_AUTH_URL\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
else
  echo "ENGINE_SSO_AUTH_URL=\"https://${OVIRT_FQDN}/ovirt-engine/sso\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
fi

echo SSO_CALLBACK_PREFIX_CHECK=false >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
echo "ENGINE_SSO_SERVICE_URL=\"https://localhost:8443/ovirt-engine/sso\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
echo "ENGINE_BASE_URL=\"https://${OVIRT_FQDN}/ovirt-engine/\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf
echo "SSO_ENGINE_URL=\"https://localhost:8443/ovirt-engine/\"" >> /etc/ovirt-engine/engine.conf.d/999-ovirt-engine.conf

export PGPASSWORD=$POSTGRES_PASSWORD

psql $POSTGRES_DB -h $POSTGRES_HOST -p $POSTGRES_PORT  -U $POSTGRES_USER -c "UPDATE vdc_options set option_value = '$HOST_INSTALL' where option_name = 'InstallVds';"
psql $POSTGRES_DB -h $POSTGRES_HOST -p $POSTGRES_PORT  -U $POSTGRES_USER -c "UPDATE vdc_options set option_value = '$HOST_USE_IDENTIFIER' where option_name = 'UseHostNameIdentifier';"

engine-config -s SSLEnabled=$HOST_ENCRYPT
engine-config -s EncryptHostCommunication=$HOST_ENCRYPT
engine-config -s BlockMigrationOnSwapUsagePercentage=$BLOCK_MIGRATION_ON_SWAP_USAGE_PERCENTAGE

su -m -s /bin/python ovirt /usr/share/ovirt-engine/services/ovirt-engine/ovirt-engine.py start
