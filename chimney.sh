#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires sudo privileges. Please enter your password:"
  exec sudo "$0" "$@" # This re-executes the script with sudo
fi

# setup variables
export CLUSTER=0chaincluster
export DELEGATE_WALLET=0chainclientId
export READ_PRICE=0chainreadPrice
export WRITE_PRICE=0chainwritePrice
export MIN_STAKE=0chainminStake
export MAX_STAKE=0chainmaxStake
export NO_OF_DELEGATES=0chaindelegates
export SERVICE_CHARGE=0chainserviceCharge
export GF_ADMIN_USER=0chaingfadminuser
export GF_ADMIN_PASSWORD='0chaingfadminpassword'
export PROJECT_ROOT=/var/0chain/blobber
export BLOCK_WORKER_URL=0chainblockworker
export BLOBBER_HOST=0chainblobberhost

export VALIDATOR_WALLET_ID=0chainvalwalletid
export VALIDATOR_WALLET_PUBLIC_KEY=0chainvalwalletpublickey
export VALIDATOR_WALLET_PRIV_KEY=0chainvalwalletprivkey
export BLOBBER_WALLET_ID=0chainblobwalletid
export BLOBBER_WALLET_PUBLIC_KEY=0chainblobwalletpublickey
export BLOBBER_WALLET_PRIV_KEY=0chainblobwalletprivkey

export DEBIAN_FRONTEND=noninteractive

export PROJECT_ROOT_SSD=/var/0chain/blobber/ssd
export PROJECT_ROOT_HDD=/var/0chain/blobber/hdd

export BRANCH_NAME=main

sudo apt update

if dpkg --get-selections | grep -q "unattended-upgrades"; then
  echo "unattended-upgrades is installed. removing it"
  sudo apt-get remove -y --purge unattended-upgrades
else
  echo "unattended-upgrades is not installed. Nothing to do."
fi

install_tools_utilities() {
  REQUIRED_PKG=$1
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG | grep "install ok installed")
  echo -e "\e[37mChecking for $REQUIRED_PKG if it is already installed. \e[73m"
  if [ "" = "$PKG_OK" ]; then
    echo -e "\e[31m  No $REQUIRED_PKG is found on the server. \e[13m\e[32m$REQUIRED_PKG installed. \e[23m \n"
    sudo apt --yes install $REQUIRED_PKG &>/dev/null
  else
    echo -e "\e[32m  $REQUIRED_PKG is already installed on the server/machine.  \e[23m \n"
  fi
}
check_port_443() {
  PORT=443
  command -v netstat >/dev/null 2>&1 || {
    echo >&2 "netstat command not found. Exiting."
    exit 1
  }

  if netstat -tulpn | grep ":$PORT" >/dev/null; then
    echo "Port $PORT is in use."
    echo "Please stop the process running on port $PORT and run the script again"
    exit 1
  else
    echo "Port $PORT is not in use."
  fi
}

install_tools_utilities unzip
install_tools_utilities curl
install_tools_utilities containerd
install_tools_utilities docker.io
install_tools_utilities systemd
install_tools_utilities "systemd-timesyncd"
install_tools_utilities ufw
install_tools_utilities ntp
install_tools_utilities ntpdate
install_tools_utilities net-tools
install_tools_utilities python3

sudo ufw allow 123/udp
sudo ufw allow out to any port 123
sudo systemctl stop ntp
sudo ntpdate pool.ntp.org
sudo systemctl start ntp
sudo systemctl enable ntp



# download docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

## cleanup server before starting the deployment
if [ -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
  echo "previous deployment exists. Clean it up..."
  docker-compose -f ${PROJECT_ROOT}/docker-compose.yml down --volumes
  docker system prune --volumes --force
  rm -rf ${PROJECT_ROOT} || true
fi

echo "checking if ports are available..."
check_port_443

# #Disk setup
# mkdir -p $PWD/disk-setup/
# wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/${BRANCH_NAME}/disk-setup/disk_setup.sh -O $PWD/disk-setup/disk_setup.sh
# wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/${BRANCH_NAME}/disk-setup/disk_func.sh -O $PWD/disk-setup/disk_func.sh

# sudo chmod +x $PWD/disk-setup/disk_setup.sh
# bash $PWD/disk-setup/disk_setup.sh $PROJECT_ROOT_SSD $PROJECT_ROOT_HDD
mkdir -p $PROJECT_ROOT_SSD
mkdir -p ${PROJECT_ROOT_HDD}/pg_hdd_data

# provide required permission for tablespace volume to mount to postgres
chown -R "999:999" ${PROJECT_ROOT_HDD}/pg_hdd_data

# generate password for portainer
echo -n ${GF_ADMIN_PASSWORD} >/tmp/portainer_password

#### ---- Start Blobber Setup ----- ####

FOLDERS_TO_CREATE="config sql bin monitoringconfig keys_config"

for i in ${FOLDERS_TO_CREATE}; do
  folder=${PROJECT_ROOT}/${i}
  echo "creating folder: $folder"
  mkdir -p $folder
done

ls -al $PROJECT_ROOT

# download and unzip files
curl -L "https://github.com/0chain/zcnwebappscripts/raw/${BRANCH_NAME}/artifacts/blobber-files.zip" -o /tmp/blobber-files.zip
unzip -o /tmp/blobber-files.zip -d ${PROJECT_ROOT}
rm /tmp/blobber-files.zip

curl -L "https://github.com/0chain/zcnwebappscripts/raw/${BRANCH_NAME}/artifacts/chimney-dashboard.zip" -o /tmp/chimney-dashboard.zip
unzip /tmp/chimney-dashboard.zip -d ${PROJECT_ROOT}
rm /tmp/chimney-dashboard.zip

# create 0chain_blobber.yaml file
echo "creating 0chain_blobber.yaml"
curl -L "https://github.com/0chain/zcnwebappscripts/raw/${BRANCH_NAME}/config/0chain_blobber.yaml" -o ${PROJECT_ROOT}/config/0chain_blobber.yaml
curl -L "https://github.com/0chain/zcnwebappscripts/raw/${BRANCH_NAME}/config/0chain_validator.yaml" -o ${PROJECT_ROOT}/config/0chain_validator.yaml

echo "updating write_price"
sed -i "s/write_price.*/write_price: ${WRITE_PRICE}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating read_price"
sed -i "s/read_price.*/read_price: ${READ_PRICE}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating delegate_wallet"
sed -i "s/delegate_wallet.*/delegate_wallet: ${DELEGATE_WALLET}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating num_delegates"
sed -i "s/num_delegates.*/num_delegates: ${NO_OF_DELEGATES}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating num_delegates in 0chain_validator.yaml"
sed -i "s/num_delegates.*/num_delegates: ${NO_OF_DELEGATES}/g" ${PROJECT_ROOT}/config/0chain_validator.yaml

echo "updating service_charge"
sed -i "s/service_charge.*/service_charge: ${SERVICE_CHARGE}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating block_worker"
sed -i "s|block_worker.*|block_worker: ${BLOCK_WORKER_URL}|g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating username"
rev ${PROJECT_ROOT}/config/0chain_blobber.yaml | sed -i "s/.*username.*/  username: ${GF_ADMIN_USER}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating password"
rev ${PROJECT_ROOT}/config/0chain_blobber.yaml | sed -i "s/.*password.*/  password: ${GF_ADMIN_PASSWORD}/g" ${PROJECT_ROOT}/config/0chain_blobber.yaml

echo "updating service_charge"
sed -i "s/service_charge.*/service_charge: ${SERVICE_CHARGE}/g" ${PROJECT_ROOT}/config/0chain_validator.yaml

echo "updating block_worker"
sed -i "s|block_worker.*|block_worker: ${BLOCK_WORKER_URL}|g" ${PROJECT_ROOT}/config/0chain_validator.yaml

### Create minio_config.txt file
echo "creating minio_config.txt"
cat <<EOF >${PROJECT_ROOT}/keys_config/minio_config.txt
block_worker: ${BLOCK_WORKER_URL}
EOF

### Caddyfile
echo "creating Caddyfile"
cat <<EOF >${PROJECT_ROOT}/Caddyfile
(cors) {
  @cors_preflight method OPTIONS
  @cors header Origin {args.0}

  handle @cors_preflight {
    header Access-Control-Allow-Origin "*"
    header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Max-Age "3600"
    respond "" 204
  }

  handle @cors {
    header Access-Control-Allow-Origin "*"
    header Access-Control-Expose-Headers "Link"
  }
}

{
   acme_ca https://acme.ssl.com/sslcom-dv-ecc
    acme_eab {
        key_id 73c05aaf847a
        mac_key 2RgDeFUTLy898F-4lcDesaWUc91IADS1Lv4_QVknhlY
    }
   email   b.manu199@gmail.com
}

${BLOBBER_HOST} {
  import cors https://${BLOBBER_HOST}
  log {
    output file /var/log/access.log {
      roll_size 1gb
      roll_keep 5
      roll_keep_for 720h
    }
  }

  route {
    reverse_proxy blobber:5051
  }

  route /validator* {
    uri strip_prefix /validator
    reverse_proxy validator:5061
  }

  route /portainer* {
    uri strip_prefix /portainer
    header Access-Control-Allow-Methods "POST,PATCH,PUT,DELETE, GET, OPTIONS"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Allow-Origin "*"
    header Cache-Control max-age=3600
    reverse_proxy portainer:9000
  }

  route /monitoring* {
    uri strip_prefix /monitoring
    header Access-Control-Allow-Methods "POST,PATCH,PUT,DELETE, GET, OPTIONS"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Allow-Origin "*"
    header Cache-Control max-age=3600
    reverse_proxy monitoringapi:3001
  }

  route /grafana* {
    uri strip_prefix /grafana
    reverse_proxy grafana:3000
  }
}

EOF

### docker-compose.yaml
echo "creating docker-compose file"
cat <<EOF >${PROJECT_ROOT}/docker-compose.yml
---
version: "3"
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_HOST_AUTH_METHOD: trust
      POSTGRES_USER: blobber_user
      POSTGRES_DB: blobber_meta
      POSTGRES_PASSWORD: blobber
      SLOW_TABLESPACE_PATH: /var/lib/postgresql/hdd
      SLOW_TABLESPACE: hdd_tablespace
    volumes:
      - ${PROJECT_ROOT_SSD}/data/postgresql:/var/lib/postgresql/data
      - ${PROJECT_ROOT_HDD}/pg_hdd_data:/var/lib/postgresql/hdd
      - ${PROJECT_ROOT}/postgresql.conf:/var/lib/postgresql/postgresql.conf
      - ${PROJECT_ROOT}/sql_init:/docker-entrypoint-initdb.d
    command: postgres -c config_file=/var/lib/postgresql/postgresql.conf
    networks:
      default:
    restart: "always"

  validator:
    image: 0chaindev/validator:sprint-1.11
    environment:
      - DOCKER= true
    volumes:
      - ${PROJECT_ROOT}/config:/validator/config
      - ${PROJECT_ROOT_HDD}/data:/validator/data
      - ${PROJECT_ROOT_HDD}/log:/validator/log
      - ${PROJECT_ROOT}/keys_config:/validator/keysconfig
    command: ./bin/validator --port 5061 --hostname ${BLOBBER_HOST} --deployment_mode 0 --keys_file keysconfig/b0vnode01_keys.txt --log_dir /validator/log --hosturl https://${BLOBBER_HOST}/validator
    networks:
      default:
    restart: "always"

  blobber:
    image: 0chaindev/blobber:sprint-1.11
    environment:
      DOCKER: "true"
      DB_NAME: blobber_meta
      DB_USER: blobber_user
      DB_PASSWORD: blobber
      DB_PORT: "5432"
      DB_HOST: postgres
    depends_on:
      - validator
    links:
      - validator:validator
    volumes:
      - ${PROJECT_ROOT}/config:/blobber/config
      - ${PROJECT_ROOT_HDD}/files:/blobber/files
      - ${PROJECT_ROOT_HDD}/data:/blobber/data
      - ${PROJECT_ROOT_HDD}/log:/blobber/log
      - ${PROJECT_ROOT}/keys_config:/blobber/keysconfig # keys and minio config
      - ${PROJECT_ROOT_HDD}/data/tmp:/tmp
      - ${PROJECT_ROOT}/sql:/blobber/sql
    command: ./bin/blobber --port 5051 --grpc_port 31501 --hostname ${BLOBBER_HOST}  --deployment_mode 0 --keys_file keysconfig/b0bnode01_keys.txt --files_dir /blobber/files --log_dir /blobber/log --db_dir /blobber/data --hosturl https://${BLOBBER_HOST}
    networks:
      default:
    restart: "always"

  caddy:
    image: caddy:2.6.4
    ports:
      - 80:80
      - 443:443
    volumes:
      - ${PROJECT_ROOT}/Caddyfile:/etc/caddy/Caddyfile
      - ${PROJECT_ROOT}/site:/srv
      - ${PROJECT_ROOT}/caddy_data:/data
      - ${PROJECT_ROOT}/caddy_config:/config
    restart: "always"

  promtail:
    image: grafana/promtail:2.8.2
    volumes:
      - ${PROJECT_ROOT_HDD}/log/:/logs
      - ${PROJECT_ROOT}/monitoringconfig/promtail-config.yaml:/mnt/config/promtail-config.yaml
    command: -config.file=/mnt/config/promtail-config.yaml
    restart: "always"

  loki:
    image: grafana/loki:2.8.2
    user: "1001"
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/loki-config.yaml:/mnt/config/loki-config.yaml
      - ${PROJECT_ROOT_HDD}/loki:/data
      - ${PROJECT_ROOT_HDD}/loki/rules:/etc/loki/rules
    command: -config.file=/mnt/config/loki-config.yaml
    restart: "always"

  prometheus:
    image: prom/prometheus:v2.44.0
    user: root
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: "always"
    depends_on:
    - cadvisor

  cadvisor:
    image: wywywywy/docker_stats_exporter:20220516
    container_name: cadvisor
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    restart: "always"

  node-exporter:
    image: prom/node-exporter:v1.5.0
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$\$|/)'
    restart: "always"

  grafana:
    image: grafana/grafana:9.5.2
    environment:
      GF_SERVER_ROOT_URL: "https://${BLOBBER_HOST}/grafana"
      GF_SECURITY_ADMIN_USER: "${GF_ADMIN_USER}"
      GF_SECURITY_ADMIN_PASSWORD: "${GF_ADMIN_PASSWORD}"
      GF_AUTH_ANONYMOUS_ENABLED: "true"
      GF_AUTH_ANONYMOUS_ORG_ROLE: "Viewer"
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yaml
      - grafana_data:/var/lib/grafana
    restart: "always"

  monitoringapi:
    image: 0chaindev/monitoringapi:latest
    restart: "always"

  agent:
    image: portainer/agent:2.18.2-alpine
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes

  portainer:
    image: portainer/portainer-ce:2.18.2-alpine
    command: '-H tcp://agent:9001 --tlsskipverify --admin-password-file /tmp/portainer_password'
    links:
      - agent:agent
    volumes:
      - portainer_data:/data
      - /tmp/portainer_password:/tmp/portainer_password

networks:
  default:
    driver: bridge

volumes:
  grafana_data:
  prometheus_data:
  portainer_data:

EOF

cat <<EOF >${PROJECT_ROOT}/keys_config/b0bnode01_keys.txt
${BLOBBER_WALLET_PUBLIC_KEY}
${BLOBBER_WALLET_PRIV_KEY}
EOF

cat <<EOF >${PROJECT_ROOT}/keys_config/b0vnode01_keys.txt
${VALIDATOR_WALLET_PUBLIC_KEY}
${VALIDATOR_WALLET_PRIV_KEY}
EOF

/usr/local/bin/docker-compose -f ${PROJECT_ROOT}/docker-compose.yml pull
/usr/local/bin/docker-compose -f ${PROJECT_ROOT}/docker-compose.yml up -d

while [ ! -d ${PROJECT_ROOT}/caddy_data/caddy/certificates ]; do
  echo "waiting for certificates to be provisioned"
  sleep 2
done

DASHBOARDS=${PROJECT_ROOT}/chimney-dashboard
echo "sleeping for 10secs.."
sleep 10

escapedPassword=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$GF_ADMIN_PASSWORD'''))")

sed -i "s/blobber_host/${BLOBBER_HOST}/g" ${DASHBOARDS}/homepage.json

echo "setting up chimney dashboards..."

curl -X POST -H "Content-Type: application/json" \
  -d "{\"dashboard\":$(cat ${DASHBOARDS}/homepage.json)}" \
  "https://${GF_ADMIN_USER}:${escapedPassword}@${BLOBBER_HOST}/grafana/api/dashboards/import"

curl -X PUT -H "Content-Type: application/json" \
  -d '{ "theme": "", "homeDashboardUID": "homepage", "timezone": "utc" }' \
  "https://${GF_ADMIN_USER}:${escapedPassword}@${BLOBBER_HOST}/grafana/api/org/preferences"

for dashboard in "${DASHBOARDS}/blobber.json" "${DASHBOARDS}/server.json" "${DASHBOARDS}/validator.json"; do
  echo -e "\nUploading dashboard: ${dashboard}"
  curl -X POST -H "Content-Type: application/json" \
    -d "@${dashboard}" \
    "https://${GF_ADMIN_USER}:${escapedPassword}@${BLOBBER_HOST}/grafana/api/dashboards/import"
  echo ""
done
