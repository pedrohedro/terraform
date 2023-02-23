#!/bin/bash -e

###------------------------------------------------------------------------------------------###

### Author:         Josue Rojas Montero

### Mail:           josue.rojas@noexternalmail.hsbc.com

### Description:    Setup of programs, users and libraries installation via local repositories

### Date:           Julio-22-2021

### Modified:       None

### Version:        1.0.0

### Script:         tableau_setup.sh

### Location:       GitHub repository

### Instructions:   Compute Engine VM Instances provisioning via Terraform

### Changes:        

###                 -

###------------------------------------------------------------------------------------------###

 

#-----------> LDAP FILES, important to request for PROD

# Important, the LDAP.json or config.json settings file is the used to query/filter LDAP Groups/Users and requires a LDAP.cer file

#TABLEAU_IDENTITY="regtbl.json"

#TABLEAU_IDENTITY="conftbl_ad.json"

#TABLEAU_IDENTITY="conftbl.json"

#TABLEAU_IDENTITY="LDAP.json"

# ---- Leyla Viera (leyla.v.dearaujo@hsbc.com) provides the LDAP .cer (HSBC CRES SHA2.renametocer)

# https://alm-confluence.systems.uk.hsbc/confluence/display/CATAD/How+to+Request+a+Production+ADLDS+Group+In+Service+Now  

#----------- LDAP FILES, important to request for PROD

 

#TABLEAU_ENVIROMENT="tableau_setup.sh"

 

TBL_ENVIRONMENT="dev"

echo "TBL_ENVIRONMENT: ${TBL_ENVIRONMENT}" >> /tmp/setup.log

if [ "${TBL_ENVIRONMENT}" = "oat_dev" ]; then

    TBL_HOST="tableau.bzdwh.oat.hsbc-10340762-bzdwh2-dev.dev.gcp.cloud.us.hsbc"

    HOST_NAME="financerisk-tableau-server-10340762-bzdwh2-dev"

elif [ "${TBL_ENVIRONMENT}" = "uat" ]; then

    TBL_HOST="tablu.bzdwh.uat.hsbc-10340762-bzdwhuat-dev.dev.gcp.cloud.us.hsbc"

    HOST_NAME="financerisk-tableau-server-10340762-bzdwhuat-dev"

elif [ "${TBL_ENVIRONMENT}" = "prod" ]; then

    TBL_HOST="tableau.bzdwh.hsbc-10340762-bzdwh-prod.prod.gcp.cloud.us.hsbc"

    HOST_NAME="financerisk-tableau-server-10340762-bzdwh-prod"

else

    TBL_HOST="tableau.bzdwh.dev.hsbc-10340762-bzdwh-dev.dev.gcp.cloud.us.hsbc"

    HOST_NAME="financerisk-tableau-server-10340762-bzdwh-dev"

fi

sudo hostnamectl set-hostname $TBL_HOST

 

#---> Local variables for Tableau service

TABLEAU_ADMIN="tsmadmin"

TABLEAU_SETUP=/tmp

TABLEAU_INST_LOG=/tmp/setup.log

TABLEAU_SRV=/etc/opt/tableau/tableau_server

TABLEAU_BASE=/opt/tableau/tableau_server/packages

TABLEAU_VER=20204.21.1217.2244

TABLEAU_SSL=/opt/tableau/tableau_server/data/ssl

TABLEAU_VAR=/var/opt/tableau/tableau_server

TABLEAU_PROXY="20-proxy.conf"

TABLEAU_STORE_LIC="internal-financerisk-configuration-bucket-${TBL_ENVIRONMENT}/offline-deactivation"

 

TABLEAU_TRIAL=true

TABLEAU_KEY=TSCT-B31D-9000-B9AC-8CD5

 

SRV_PROXY=http://intpxy6.hk.hsbc:18084/

PROXY_ENABLE=true

 

MULTINIC_INSTANCE_NIC1_IP=$(curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/1/ip)

STANDALONE_SUBNET_GATEWAY=$(curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/1/gateway)

sudo ifconfig eth1 $MULTINIC_INSTANCE_NIC1_IP netmask 255.255.255.255 broadcast $MULTINIC_INSTANCE_NIC1_IP mtu 1430

echo "1 rt1" | sudo tee -a /etc/iproute2/rt_tables

sudo ip route add $STANDALONE_SUBNET_GATEWAY src $MULTINIC_INSTANCE_NIC1_IP dev eth1 table rt1

sudo ip route add default via $STANDALONE_SUBNET_GATEWAY dev eth1 table rt1

sudo ip rule add from $MULTINIC_INSTANCE_NIC1_IP/32 table rt1

sudo ip rule add to $MULTINIC_INSTANCE_NIC1_IP/32 table rt1

sudo ip route add 192.168.196.1 src $MULTINIC_INSTANCE_NIC1_IP dev eth1 table rt1

sudo ip route add 192.168.196.0/22 dev eth1

 

RESTORE_LATESTS=false

BACKUP_ENABLED=true

echo "BACKUP_ENABLED: $BACKUP_ENABLED" >> ${TABLEAU_INST_LOG}

echo "RESTORE_LATESTS: $RESTORE_LATESTS" >> ${TABLEAU_INST_LOG}

echo "RESTORE_FILE: $RESTORE_FILE" >> ${TABLEAU_INST_LOG}

 

#Setup Tableau initial environment

if [ "$PROXY_ENABLE" = true ] ; then

    echo "${TABLEAU_BASE}/scripts.${TABLEAU_VER}/initialize-tsm -f --accepteula -a ${TABLEAU_ADMIN} --http_proxy=${SRV_PROXY}" >> ${TABLEAU_INST_LOG}

    ${TABLEAU_BASE}/scripts.${TABLEAU_VER}/initialize-tsm -f --accepteula -a ${TABLEAU_ADMIN} --http_proxy=${SRV_PROXY} >> ${TABLEAU_INST_LOG} 2>&1 &

else

    echo "${TABLEAU_BASE}/scripts.${TABLEAU_VER}/initialize-tsm -f --accepteula -a ${TABLEAU_ADMIN}" >> ${TABLEAU_INST_LOG}

    ${TABLEAU_BASE}/scripts.${TABLEAU_VER}/initialize-tsm -f --accepteula -a ${TABLEAU_ADMIN} >> ${TABLEAU_INST_LOG} 2>&1 &

fi

wait

if [ "$TABLEAU_TRIAL" = true ] ; then

    echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses activate --trial" >> ${TABLEAU_INST_LOG}

    ${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses activate --trial >> ${TABLEAU_INST_LOG} 2>&1 &

    wait

fi

#---> Proxy configuration

if [ "$PROXY_ENABLE" = true ] ; then

    MULTINIC_INSTANCE_NIC0_IP=$(curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip)

    echo $'\n' >> ${TABLEAU_SETUP}/${TABLEAU_PROXY}

    echo "no_proxy=\"localhost,127.0.0.1,${MULTINIC_INSTANCE_NIC0_IP},${TBL_HOST},${HOST_NAME},gcp-asia-east2-p-ombbusvis-tableau,*.internal\"" >> ${TABLEAU_SETUP}/${TABLEAU_PROXY}

    sudo -u tableau mkdir -p ${TABLEAU_VAR}/.config/systemd/tableau_server.conf.d/

    chown tableau:tableau ${TABLEAU_SETUP}/${TABLEAU_PROXY}

    sudo -u tableau mv ${TABLEAU_SETUP}/${TABLEAU_PROXY} ${TABLEAU_VAR}/.config/systemd/tableau_server.conf.d/

fi

if [ -v TABLEAU_KEY ] && [ ! -z "$TABLEAU_KEY" ]; then

    echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses activate -k ${TABLEAU_KEY}" >> /tmp/setup.log

    ${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses activate -k ${TABLEAU_KEY} >> /tmp/setup.log 2>&1 &

    wait

    echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses get-offline-deactivation-file -k ${TABLEAU_KEY} --output-dir ${TABLEAU_SETUP}" >> ${TABLEAU_INST_LOG}

    ${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses get-offline-deactivation-file -k ${TABLEAU_KEY} --output-dir ${TABLEAU_SETUP} >> ${TABLEAU_INST_LOG} 2>&1 &

    wait

    TBL_LIC_DATE=$(date +"%Y%m%d%H%M%S")

    echo "gsutil cp ${TABLEAU_SETUP}/deactivate.tlq gs://${TABLEAU_STORE_LIC}/deactivate_${TBL_ENVIRONMENT}_${TBL_LIC_DATE}.tlq" >> ${TABLEAU_INST_LOG}

    gsutil cp ${TABLEAU_SETUP}/deactivate.tlq gs://${TABLEAU_STORE_LIC}/deactivate_${TBL_ENVIRONMENT}_${TBL_LIC_DATE}.tlq >> ${TABLEAU_INST_LOG} 2>&1 &

    wait

    echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses list" >> ${TABLEAU_INST_LOG}

    ${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm licenses list >> ${TABLEAU_INST_LOG} 2>&1 &

    wait

fi

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm register --file ${TABLEAU_SETUP}/regtbl.json"  >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm register --file ${TABLEAU_SETUP}/regtbl.json >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm security external-ssl enable --cert-file ${TABLEAU_SSL}/financerisk-tableau-bzdwh.cloud.uk.hsbc.cer --key-file ${TABLEAU_SSL}/financerisk-tableau-bzdwh.cloud.uk.hsbc.key --trust-admin-controller-cert" >> ${TABLEAU_INST_LOG} 2>&1 &

#${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm security external-ssl enable --cert-file ${TABLEAU_SSL}/financerisk-tableau-bzdwh.cloud.uk.hsbc.cer --key-file ${TABLEAU_SSL}/financerisk-tableau-bzdwh.cloud.uk.hsbc.key --trust-admin-controller-cert >> ${TABLEAU_INST_LOG} 2>&1 &

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply --ignore-prompt" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply --ignore-prompt >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/repository.${TABLEAU_VER}/jre/bin/keytool -importcert -file ${TABLEAU_SSL}/HSBC_CRESTEST_SHA2.crt -alias aa-lds-test-us.crestest.addev.hsbc -keystore ${TABLEAU_SRV}/tableauservicesmanagerca.jks -storepass changeit -noprompt" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/repository.${TABLEAU_VER}/jre/bin/keytool -importcert -file ${TABLEAU_SSL}/HSBC_CRESTEST_SHA2.crt -alias aa-lds-test-us.crestest.addev.hsbc -keystore ${TABLEAU_SRV}/tableauservicesmanagerca.jks -storepass changeit -noprompt >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm settings import -f ${TABLEAU_SETUP}/conftbl_gw.json" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm settings import -f ${TABLEAU_SETUP}/conftbl_gw.json >> ${TABLEAU_INST_LOG} 2>&1 &

wait

sudo chmod 555 ${TABLEAU_SETUP}/${TABLEAU_IDENTITY}

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm settings import -f ${TABLEAU_SETUP}/${TABLEAU_IDENTITY}" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm settings import -f ${TABLEAU_SETUP}/${TABLEAU_IDENTITY} >> ${TABLEAU_INST_LOG} 2>&1 &

wait

#${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm topology external-services repository enable -f ${TABLEAU_SETUP}/external_db.json -c ${TABLEAU_SSL}/tableau-postgresql.pem >> ${TABLEAU_INST_LOG} 2>&1 &

#wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm user-identity-store verify-group-mappings -v Infodir-HBMX-HBBZ-DWH-TABLEAU" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm user-identity-store verify-group-mappings -v Infodir-HBMX-HBBZ-DWH-TABLEAU >> ${TABLEAU_INST_LOG} 2>&1 &

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply --ignore-prompt" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm initialize -r" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm initialize -r >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply --ignore-prompt" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm pending-changes apply --ignore-prompt >> ${TABLEAU_INST_LOG} 2>&1 &

wait

echo "${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tabcmd initialuser --server localhost:80 -u US-SVC-DWHAdmin -p LiolY24JKEUqaLQ598Lc32HsVbL" >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tabcmd initialuser --server localhost:80 -u US-SVC-DWHAdmin -p LiolY24JKEUqaLQ598Lc32HsVbL >> ${TABLEAU_INST_LOG} 2>&1 &

wait

if [ "$RESTORE_LATESTS" = true ] ; then

    echo "Restoring Tableau from backup" >> ${TABLEAU_INST_LOG}

    echo "sudo /opt/tableau/backup/tbl_restore.sh $RESTORE_FILE" >> ${TABLEAU_INST_LOG}

    sudo /opt/tableau/backup/tbl_restore.sh $RESTORE_FILE >> ${TABLEAU_INST_LOG}

    echo "Restoration done" >> ${TABLEAU_INST_LOG}

fi

if [ "$BACKUP_ENABLED" = true ] ; then

    echo "Enabling Tableau backup" >> ${TABLEAU_INST_LOG}

    sudo crontab -u root -l > ${TABLEAU_SETUP}/cron_backup.dat

    sudo cat ${TABLEAU_SETUP}/crontab.backup >> ${TABLEAU_SETUP}/cron_backup.dat

    sudo crontab -u root ${TABLEAU_SETUP}/cron_backup.dat

    sudo rm ${TABLEAU_SETUP}/cron_backup.dat

    echo "sudo crontab -u root -l" >> ${TABLEAU_INST_LOG}

    sudo crontab -u root -l >> ${TABLEAU_INST_LOG} 2>&1 &

    echo "Backup setup done" >> ${TABLEAU_INST_LOG}

fi

echo "Setup completed." >> ${TABLEAU_INST_LOG}

${TABLEAU_BASE}/customer-bin.${TABLEAU_VER}/tsm status >> ${TABLEAU_INST_LOG}