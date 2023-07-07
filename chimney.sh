#!/bin/bash

set -e

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
export GF_ADMIN_PASSWORD=0chaingfadminpassword
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

#TODO: Fix docker installation
sudo apt update -qq
sudo apt install -qqy unzip curl containerd docker.io

# download docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

## cleanup server before starting the deployment
if [ -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
  echo "previous deployment exists. Clean it up..."
  docker-compose -f ${PROJECT_ROOT}/docker-compose.yml down --volumes
  rm -rf ${PROJECT_ROOT} || true
fi

#Disk setup
mkdir -p $PWD/disk-setup/
wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_setup.sh -O $PWD/disk-setup/disk_setup.sh
wget https://raw.githubusercontent.com/0chain/zcnwebappscripts/main/disk-setup/disk_func.sh -O $PWD/disk-setup/disk_func.sh

sudo chmod +x $PWD/disk-setup/disk_setup.sh
bash $PWD/disk-setup/disk_setup.sh $PROJECT_ROOT_SSD $PROJECT_ROOT_HDD

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
curl -L "https://github.com/0chain/zcnwebappscripts/raw/main/artifacts/blobber-files.zip" -o /tmp/blobber-files.zip
unzip -o /tmp/blobber-files.zip -d ${PROJECT_ROOT}
rm /tmp/blobber-files.zip

curl -L "https://github.com/0chain/zcnwebappscripts/raw/main/artifacts/chimney-dashboard.zip" -o /tmp/chimney-dashboard.zip
unzip /tmp/chimney-dashboard.zip -d ${PROJECT_ROOT}
rm /tmp/chimney-dashboard.zip

# create 0chain_blobber.yaml file
echo "creating 0chain_blobber.yaml"
cat <<EOF >${PROJECT_ROOT}/config/0chain_blobber.yaml
# blobber_config_change
version: "1.0"
logging:
  level: "info"
  console: true # printing log to console is only supported in development mode
# for testing
#  500 MB - 536870912
#    1 GB - 1073741824
#    2 GB - 2147483648
#    3 GB - 3221225472
#  100 GB - 107374182400
capacity: 1073741824 # 1 GB bytes total blobber capacity
read_price: ${READ_PRICE} # token / GB for reading
write_price: ${WRITE_PRICE} # token / GB / time_unit for writing
price_in_usd: false
price_worker_in_hours: 12
# the time_unit configured in Storage SC and can be given using
#
#     ./zbox sc-config
#

# min_lock_demand is value in [0; 1] range; it represents number of tokens the
# blobber earned even if a user will not read or write something
# to an allocation; the number of tokens will be calculated by the following
# formula (regarding the time_unit and allocation duration)
#
#     allocation_size * write_price * min_lock_demand
#
min_lock_demand: 0.1
# update_allocations_interval used to refresh known allocation objects from SC
update_allocations_interval: 1m
# maximum limit on the number of combined directories and files on each allocation
max_dirs_files: 50000
# delegate wallet (must be set)
delegate_wallet: '${DELEGATE_WALLET}'
# maximum allowed number of stake holders
num_delegates: ${NO_OF_DELEGATES}
# service charge of the blobber
service_charge: ${SERVICE_CHARGE}
# min submit from miners
min_submit: 50
# min confirmation from sharder
min_confirmation: 50
block_worker: ${BLOCK_WORKER_URL}
rate_limiters:
  # Rate limiters will use this duration to clean unused token buckets.
  # If it is 0 then token will expire in 10 years.
  default_token_expire_duration: 5m
  # If blobber is behind some proxy eg. nginx, cloudflare, etc.
  proxy: true
  # Rate limiter is applied with two parameters. One is ip-address and other is clientID.
  # Rate limiter will track both parameters independently and will block request if both
  # ip-address or clientID has reached its limit
  # Blobber may not provide any rps values and default will work fine.

  # Commit Request Per second. Commit endpoint is resource intensive.
  # Default is 0.5
  commit_rps: 1600
  # File Request Per Second. This rps is used to rate limit basically upload and download requests.
  # Its better to have 2 request per second. Default is 1
  file_rps: 1600
  # Object Request Per Second. This rps is used to rate limit GetReferencePath, GetObjectTree, etc.
  # which is resource intensive. Default is 0.5
  object_rps: 1600
  # General Request Per Second. This rps is used to rate limit endpoints like copy, rename, get file metadata,
  # get paginated refs, etc. Default is 5
  general_rps: 1600
server_chain:
  id: "0afc093ffb509f059c55478bc1a60351cef7b4e9c008a53a6cc8241ca8617dfe"
  owner: "edb90b850f2e7e7cbd0a1fa370fdcc5cd378ffbec95363a7bc0e5a98b8ba5759"
  genesis_block:
    id: "ed79cae70d439c11258236da1dfa6fc550f7cc569768304623e8fbd7d70efae4"
  signature_scheme: "bls0chain"
contentref_cleaner:
  frequency: 30
  tolerance: 3600
openconnection_cleaner:
  frequency: 30
  tolerance: 3600 # 60 * 60
writemarker_redeem:
  frequency: 10
  num_workers: 5
readmarker_redeem:
  frequency: 10
  num_workers: 5
challenge_response:
  frequency: 10
  num_workers: 5
  max_retries: 20
healthcheck:
  frequency: 60m # send healthcheck to miners every 60 minutes
pg:
  user: postgres
  password: postgres
db:
  name: blobber_meta
  user: blobber_user
  password: blobber
  host: postgres
  port: 5432
storage:
  files_dir: "/path/to/hdd"
  #  sha256 hash will have 64 characters of hex encoded length. So if dir_level is [2,2] this means for an allocation id
  #  "4c9bad252272bc6e3969be637610d58f3ab2ff8ca336ea2fadd6171fc68fdd56" directory below will be created.
  #  alloc_dir = {files_dir}/4c/9b/ad252272bc6e3969be637610d58f3ab2ff8ca336ea2fadd6171fc68fdd56
  #
  #  So this means, there will maximum of 16^4 = 65536 numbers directories for all allocations stored by blobber.
  #  Similarly for some file_hash "ef935503b66b1ce026610edf18bffd756a79676a8fe317d951965b77a77c0227" with dir_level [2, 2, 1]
  #  following path is created for the file:
  # {alloc_dir}/ef/93/5/503b66b1ce026610edf18bffd756a79676a8fe317d951965b77a77c0227
  alloc_dir_level: [2, 1]
  file_dir_level: [2, 2, 1]
disk_update:
  # defaults to true. If false, blobber has to manually update blobber's capacity upon increase/decrease
  # If blobber has to limit its capacity to 5% of its capacity then it should turn automaci_update to false.
  automatic_update: true
  blobber_update_interval: 5m # In minutes
# integration tests related configurations
integration_tests:
  # address of the server
  address: host.docker.internal:15210
  # lock_interval used by nodes to request server to connect to blockchain
  # after start
  lock_interval: 1s
admin:
  username: "${GF_ADMIN_USER}"
  password: "${GF_ADMIN_PASSWORD}"

EOF

### Create 0chain_validator.yaml file
echo "creating 0chain_validator.yaml"
cat <<EOF >${PROJECT_ROOT}/config/0chain_validator.yaml
# validator_config_change
version: 1.0
# delegate wallet (must be set)
delegate_wallet: '${DELEGATE_WALLET}'
# maximum allowed number of stake holders
num_delegates: 50
# service charge of related blobber
service_charge: ${SERVICE_CHARGE}
block_worker: ${BLOCK_WORKER_URL}
rate_limiters:
  # Rate limiters will use this duration to clean unused token buckets.
  # If it is 0 then token will expire in 10 years.
  default_token_expire_duration: 5m
  # If blobber is behind some proxy eg. nginx, cloudflare, etc.
  proxy: true
logging:
  level: "error"
  console: true # printing log to console is only supported in development mode
healthcheck:
  frequency: 60s # send healthcheck to miners every 60 seconds
server_chain:
  id: "0afc093ffb509f059c55478bc1a60351cef7b4e9c008a53a6cc8241ca8617dfe"
  owner: "edb90b850f2e7e7cbd0a1fa370fdcc5cd378ffbec95363a7bc0e5a98b8ba5759"
  genesis_block:
    id: "ed79cae70d439c11258236da1dfa6fc550f7cc569768304623e8fbd7d70efae4"
  signature_scheme: "bls0chain"
# integration tests related configurations
integration_tests:
  # address of the server
  address: host.docker.internal:15210
  # lock_interval used by nodes to request server to connect to blockchain
  # after start
  lock_interval: 1s

EOF

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
    volumes:
      - ${PROJECT_ROOT_SSD}/data/postgresql:/var/lib/postgresql/data
      - ${PROJECT_ROOT}/postgresql.conf:/var/lib/postgresql/postgresql.conf
      - ${PROJECT_ROOT}/sql_init:/docker-entrypoint-initdb.d
    command: postgres -c config_file=/var/lib/postgresql/postgresql.conf
    networks:
      default:
    restart: "always"

  postgres-post:
    image: postgres:14
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_HOST_AUTH_METHOD: trust
      POSTGRES_PORT: "5432"
      POSTGRES_USER: postgres
    volumes:
      - ${PROJECT_ROOT}/bin:/blobber/bin
      # - /var/0chain/blobber/sql:/blobber/sql
    command: bash /blobber/bin/postgres-entrypoint.sh
    links:
      - postgres:postgres

  validator:
    image: 0chaindev/validator:staging
    environment:
      - DOCKER= true
    depends_on:
      - postgres-post
    links:
      - postgres-post:postgres-post
    volumes:
      - ${PROJECT_ROOT}/config:/validator/config
      - ${PROJECT_ROOT_HDD}/data:/validator/data
      - ${PROJECT_ROOT_HDD}/log:/validator/log
      - ${PROJECT_ROOT}/keys_config:/validator/keysconfig
    ports:
      - "5061:5061"
    command: ./bin/validator --port 5061 --hostname ${BLOBBER_HOST} --deployment_mode 0 --keys_file keysconfig/b0vnode01_keys.txt --log_dir /validator/log --hosturl https://${BLOBBER_HOST}/validator
    networks:
      default:
    restart: "always"

  blobber:
    image: 0chaindev/blobber:staging
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
    ports:
      - "5051:5051"
      - "31501:31501"
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
    ports:
      - "9080:9080"
    restart: "always"

  loki:
    image: grafana/loki:2.8.2
    user: "1001"
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/loki-config.yaml:/mnt/config/loki-config.yaml
    command: -config.file=/mnt/config/loki-config.yaml
    ports:
      - "3100:3100"
    restart: "always"

  prometheus:
    image: prom/prometheus:v2.44.0
    user: root
    ports:
      - "9090:9090"
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
    ports:
    - 9487:9487
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
    expose:
      - 9100
    restart: "always"

  grafana:
    image: grafana/grafana:9.5.2
    environment:
      GF_SERVER_ROOT_URL: "https://${BLOBBER_HOST}/grafana"
      GF_SECURITY_ADMIN_USER: ${GF_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GF_ADMIN_PASSWORD}
    volumes:
      - ${PROJECT_ROOT}/monitoringconfig/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yaml
      - grafana_data:/var/lib/grafana
    ports:
      - "3040:3000"
    restart: "always"

  monitoringapi:
    image: 0chaindev/chimney:monitoringapi-latest
    ports:
      - "3001:3001"
    restart: "always"

  agent:
    image: portainer/agent:2.18.2-alpine
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
  portainer:
    image: portainer/portainer-ce:2.18.2-alpine
    command: '-H tcp://agent:9001 --tlsskipverify --admin-password-file /tmp/portainer_password'
    ports:
      - "9000:9000"
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

sed -i "s/blobber_host/${BLOBBER_HOST}/g" ${DASHBOARDS}/homepage.json

echo "setting up chimney dashboards..."

curl -X POST -H "Content-Type: application/json" \
      -d "{\"dashboard\":$(cat ${DASHBOARDS}/homepage.json)}" \
      "https://${GF_ADMIN_USER}:${GF_ADMIN_PASSWORD}@${BLOBBER_HOST}/grafana/api/dashboards/import"


curl -X PUT -H "Content-Type: application/json" \
    -d '{ "theme": "", "homeDashboardUID": "homepage", "timezone": "utc" }' \
    "https://${GF_ADMIN_USER}:${GF_ADMIN_PASSWORD}@${BLOBBER_HOST}/grafana/api/org/preferences"


for dashboard in "${DASHBOARDS}/blobber.json" "${DASHBOARDS}/server.json" "${DASHBOARDS}/validator.json"; do
    echo -e "\nUploading dashboard: ${dashboard}"
    curl -X POST -H "Content-Type: application/json" \
          -d "@${dashboard}" \
        "https://${GF_ADMIN_USER}:${GF_ADMIN_PASSWORD}@${BLOBBER_HOST}/grafana/api/dashboards/import"
done
