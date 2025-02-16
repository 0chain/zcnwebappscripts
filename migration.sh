#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires sudo privileges. Please enter your password:"
  exec sudo "$0" "$@" # This re-executes the script with sudo
fi

MIGRATION_ROOT=$HOME/s3migration/state
MIGRATION_LOGS=$HOME/s3migration/logs
MINIO_USERNAME=0chainminiousername
MINIO_PASSWORD=0chainminiopassword
MINIO_TOKEN=0chainminiotoken
ACCESS_KEY=0chainaccesskey
SECRET_KEY=0chainsecretkey
ALLOCATION=0chainallocation
BUCKET=0chainbucket
BLIMP_DOMAIN=blimpdomain
WALLET_ID=0chainwalletid
WALLET_PUBLIC_KEY=0chainwalletpublickey
WALLET_PRIVATE_KEY=0chainwalletprivatekey
BLOCK_WORKER_URL=0chainblockworker
SOURCE=0chainsource

# optional params
CONCURRENCY=1
DELETE_SOURCE=0chaindeletesource
ENCRYPT=0chainencrypt
REGION=0chainregion
SKIP=0chainskip
NEWER_THAN=0chainnewerthan
OLDER_THAN=0chainolderthan
PREFIX=0chainprefix
RESUME=0chainresume
MIGRATE_TO=0chainmigrateto
WORKING_DIR=0chainwd
CONFIG_DIR=$HOME/.zcn
CONFIG_DIR_MIGRATION=${CONFIG_DIR}/migration # to store wallet.json, config.json, allocation.json
DRIVE_CLIENT_ID=0chainclientid
DRIVE_CLIENT_SECRET=0chainclientsecret

sudo apt update
DEBIAN_FRONTEND=noninteractive sudo apt install -y unzip curl containerd docker.io jq
snap install yq

if [[ -d $HOME/.zcn/docker-compose.yml ]]; then
  MINIO_TOKEN=$(yq '.services.minioserver.environment.MINIO_AUDIT_WEBHOOK_ENDPOINT' $HOME/.zcn/docker-compose.yml)
  MINIO_USERNAME=$(yq '.services.minioserver.environment.MINIO_ROOT_USER' $HOME/.zcn/docker-compose.yml)
  MINIO_PASSWORD=$(yq '.services.minioserver.environment.MINIO_ROOT_PASSWORD' $HOME/.zcn/docker-compose.yml)
fi

#Setting latest docker image wrt latest release
export DOCKER_TAG=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/blimp-minioserver/tags?page_size=100 | jq -r '.results[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
export export S3MGRT_AGENT_TAG=$(curl -s https://registry.hub.docker.com/v2/repositories/0chaindev/s3mgrt/tags?page_size=100 | jq -r '.results[].name' | sort -V | tail -n 1)

sudo apt update
DEBIAN_FRONTEND=noninteractive sudo apt install -y unzip curl containerd docker.io jq net-tools
snap install yq

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

echo "download docker-compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

sudo curl -L "https://s3-mig-binaries.s3.us-east-2.amazonaws.com/s3mgrt" -o /usr/local/bin/s3mgrt
chmod +x /usr/local/bin/s3mgrt

mkdir -p ${MIGRATION_ROOT}

sudo docker-compose -f ${CONFIG_DIR}/docker-compose.yml down
rm -rf ${MIGRATION_ROOT}/*

echo "checking if ports are available..."
check_port_443

mkdir -p ${MIGRATION_LOGS}
mkdir -p ${CONFIG_DIR}
mkdir -p ${CONFIG_DIR_MIGRATION}

MINIO_ROOT_USER=$(cat docker-compose.yml |  yq e '.services.minioserver.environment | select(.MINIO_ROOT_USER != null) | .MINIO_ROOT_USER')
MINIO_ROOT_PASSWORD=$(cat docker-compose.yml |  yq e '.services.minioserver.environment | select(.MINIO_ROOT_PASSWORD != null) | .MINIO_ROOT_PASSWORD')

# create wallet.json
cat <<EOF >${CONFIG_DIR_MIGRATION}/wallet.json
{
  "client_id": "${WALLET_ID}",
  "client_key": "${WALLET_PUBLIC_KEY}",
  "keys": [
    {
      "public_key": "${WALLET_PUBLIC_KEY}",
      "private_key": "${WALLET_PRIVATE_KEY}"
    }
  ],
  "mnemonics": "0chainmnemonics",
  "version": "1.0"
}
EOF

# create config.yaml
cat <<EOF >${CONFIG_DIR_MIGRATION}/config.yaml
block_worker: ${BLOCK_WORKER_URL}
signature_scheme: bls0chain
min_submit: 50
min_confirmation: 50
confirmation_chain_length: 3
max_txn_query: 5
query_sleep_time: 5
EOF

# conform if the wallet belongs to an allocationID
curl -L https://github.com/0chain/zboxcli/releases/download/v1.4.4/zbox-linux.tar.gz -o /tmp/zbox-linux.tar.gz
sudo tar -xvf /tmp/zbox-linux.tar.gz -C /usr/local/bin

_contains() { # Check if space-separated list $1 contains line $2
  echo "$1" | tr ' ' '\n' | grep -F -x -q "$2"
}

allocations=$(/usr/local/bin/zbox listallocations --configDir ${CONFIG_DIR_MIGRATION} --silent --json | jq -r ' .[] | .id')

if ! _contains "${allocations}" "${ALLOCATION}"; then
  echo "given allocation does not belong to the wallet"
  exit 1
fi

cat <<EOF >${CONFIG_DIR_MIGRATION}/allocation.txt
$ALLOCATION
EOF

# create a seperate folder to store caddy files
mkdir -p ${CONFIG_DIR}/caddyfiles

cat <<EOF >${CONFIG_DIR}/caddyfiles/Caddyfile
{
   acme_ca https://acme.ssl.com/sslcom-dv-ecc
    acme_eab {
        key_id 7262ffd58bd9
        mac_key LTjZs0DOMkspvR7Tsp8ke5ns5yNo9fgiLNWKA65sHPQ
    }
   email   store@zus.network
}
import /etc/caddy/*.caddy
EOF

cat <<EOF >${CONFIG_DIR}/caddyfiles/migration.caddy
${BLIMP_DOMAIN} {
	route /s3migration {
		reverse_proxy s3mgrt:8080
	}
}

EOF

# create docker-compose
cat <<EOF >${CONFIG_DIR}/docker-compose.yml
version: '3.8'
services:
  caddy:
    image: caddy:2.6.4
    ports:
      - 80:80
      - 443:443
    volumes:
      - ${CONFIG_DIR}/caddyfiles:/etc/caddy
      - ${CONFIG_DIR}/caddy/site:/srv
      - ${CONFIG_DIR}/caddy/caddy_data:/data
      - ${CONFIG_DIR}/caddy/caddy_config:/config
    restart: "always"

  db:
    image: postgres:13-alpine
    container_name: postgres-db
    restart: always
    command: -c "log_statement=all"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - db:/var/lib/postgresql/data

  api:
    image: 0chaindev/blimp-logsearchapi:${DOCKER_TAG}
    depends_on:
      - db
    environment:
      LOGSEARCH_PG_CONN_STR: "postgres://postgres:postgres@postgres-db/postgres?sslmode=disable"
      LOGSEARCH_AUDIT_AUTH_TOKEN: 12345
      MINIO_LOG_QUERY_AUTH_TOKEN: 12345
      LOGSEARCH_DISK_CAPACITY_GB: 5
    links:
      - db

  minioserver:
    image: 0chaindev/blimp-minioserver:${DOCKER_TAG}
    container_name: minioserver
    command: ["minio", "gateway", "zcn"]
    environment:
      MINIO_AUDIT_WEBHOOK_ENDPOINT: ${MINIO_TOKEN}
      MINIO_AUDIT_WEBHOOK_AUTH_TOKEN: 12345
      MINIO_AUDIT_WEBHOOK_ENABLE: "on"
      MINIO_ROOT_USER: ${MINIO_USERNAME}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
      MINIO_BROWSER: "OFF"
    links:
      - api:api
    volumes:
      - ${CONFIG_DIR_MIGRATION}:/root/.zcn
    expose:
      - "9000"

  minioclient:
    image: 0chaindev/blimp-clientapi:${DOCKER_TAG}
    container_name: minioclient
    depends_on:
      - minioserver
    environment:
      MINIO_SERVER: "minioserver:9000"

  s3mgrt:
    image: 0chaindev/s3mgrt:${S3MGRT_AGENT_TAG}
    restart: always
    environment:
      BUCKET: "${BUCKET}"
    volumes:
      - ${MIGRATION_ROOT}:/migrate
      - ${MIGRATION_LOGS}:/migratelogs

volumes:
  db:
    driver: local

EOF

/usr/local/bin/docker-compose -f ${CONFIG_DIR}/docker-compose.yml pull
/usr/local/bin/docker-compose -f ${CONFIG_DIR}/docker-compose.yml up -d

CERTIFICATES_DIR=caddy/caddy_data/caddy/certificates/acme.ssl.com-sslcom-dv-ecc

while [ ! -d ${CONFIG_DIR}/${CERTIFICATES_DIR}/${BLIMP_DOMAIN} ]; do
  echo "waiting for certificates to be provisioned"
  sleep 2
done


echo "Starting migration..."
echo ""

flags="--configDir ${CONFIG_DIR_MIGRATION} --source ${SOURCE} --wd ${MIGRATION_ROOT} --access-key ${ACCESS_KEY}  --secret-key ${SECRET_KEY} --allocation ${ALLOCATION} --bucket ${BUCKET} "

if [ $ENCRYPT == "true" ]; then flags=$flags" --encrypt true"; fi
if [ $DELETE_SOURCE == "true" ]; then flags=$flags" --delete-source true"; fi
if [ $REGION != "0chainregion" ]; then flags=$flags"--region ${REGION}"; fi
if [ $SKIP != "0chainskip" ]; then flags=$flags" --skip ${SKIP}"; fi
if [ $NEWER_THAN != "0chainnewerthan" ]; then flags=$flags" --newer-than ${NEWER_THAN}"; fi
if [ $OLDER_THAN != "0chainolderthan" ]; then flags=$flags" --older-than ${OLDER_THAN}"; fi
if [ $PREFIX != "0chainprefix" ]; then flags=$flags" --prefix ${PREFIX}"; fi
if [ $RESUME == "true" ]; then flags=$flags" --resume ${RESUME}"; fi
if [ $MIGRATE_TO != "0chainmigrateto" ]; then flags=$flags" --migrate-to ${MIGRATE_TO}"; fi
if [ $DRIVE_CLIENT_ID != "0chainclientid" ]; then flags=$flags" --client-id ${DRIVE_CLIENT_ID}"; fi
if [ $DRIVE_CLIENT_SECRET != "0chainclientsecret" ]; then flags=$flags" --client-secret ${DRIVE_CLIENT_SECRET}"; fi
# if [ $WORKING_DIR != "0chainwd" ]; then flags=$flags" --wd ${WORKING_DIR}"; fi

cd ${MIGRATION_LOGS}
/usr/local/bin/s3mgrt migrate $flags

echo  $flags
echo "Migration complete..."
